// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.11;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Rewards is ReentrancyGuard, AccessControl {

    bytes32 public constant LENDING_CONTRACTS_ROLE = keccak256("LENDING_CONTRACTS_ROLE");
    address public rewardTokenAddress;
    uint256 public rewardPerEpoch; //Amount of reward tokens which users can get in epoch
    uint256 public epochDuration; //Period of time for which reward is appointed
    uint256 private tokenPerSupply; //Reward tokens per supply
    uint256 private rewardDuration; //Min amount of time for receive reward
    uint256 private precision = 1e18; //Decimals of reward token
    uint256 private totalAmountSupplied; //Total amount supplied of all users
    uint256 private lastTimeChangedTps; //Last block.timestamp then tps changed

    struct User {
        uint256 amountSupplied; //Amount supplied 
        uint256 missedReward; //Amount of reward tokens that user missed
    }

    //List information about users
    //users[addressOfUser] = User struct
    mapping(address => User) public users;

    //Emitted then user supply amount
    event Supply(address indexed user, uint256 amount);

    //Emitted then user `withdraw`
    event Withdraw(
        address indexed user,
        uint256 amount,
        uint256 totalAmountSupplied
    );

    //Emitted then user `claim` rewards
    event Claim(address indexed user, uint256 amount);

    //Emitted then admin `setParameters`
    event ParametersSet(
        uint256 reward,
        uint256 epochDuration,
        uint256 rewardDuration
    );

    //Emitted then admin `withdraw`
    event AdminWithdraw(address indexed receiver, uint256 amount);

    /**
     * @dev Creates a reward contract.
     */
    constructor(
        uint256 _rewardPerEpoch,
        uint256 _epochDuration,
        uint256 _rewardDuration,
        address _lendingContractAddress,
        address _rewardTokenAddress
        ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(LENDING_CONTRACTS_ROLE, _lendingContractAddress);
        rewardTokenAddress = _rewardTokenAddress;
        rewardPerEpoch = _rewardPerEpoch;
        epochDuration = _epochDuration;
        rewardDuration = _rewardDuration;
        lastTimeChangedTps = block.timestamp;
    }

    /**
     * @dev Utility function for using token
     */
    function _safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // Transfer selector `bytes4(keccak256(bytes('transfer(address,uint256)')))` should be equal to 0xa9059cbb
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TRANSFER_FAILED"
        );
    }

    /**
     * @dev Set lending contracts addresses.
     * @param _address contract address
     */
    function setLendingContractAddress(address _address)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _grantRole(LENDING_CONTRACTS_ROLE, _address);
    }

    /**
     * @dev Revoke lending contracts addresses.
     * @param _address contract address
     */
    function revokeLendingContractAddress(address _address)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _revokeRole(LENDING_CONTRACTS_ROLE, _address);
    }

    /**
     * @dev Set reward token contract address.
     * @param _address contract address
     */
    function setRewardTokenAddress(address _address)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        rewardTokenAddress = _address;
    }

    /**
     * @notice Send Tokens to user. Used only by lending contracts
     * @param _user user address
     * @param _amount amount of reward Tokens
     */
    function sendTokensToUser(address _user, uint256 _amount)
        external
        onlyRole(LENDING_CONTRACTS_ROLE)
    {
        require(rewardTokenAddress != address(0x0), "Zero address of reward token");
        _safeTransfer(rewardTokenAddress, _user, _amount);
    }

    /**
     * @notice Withdraw any amount of Tokens to admin address.
     * @param _admin admin address
     * @param _amount amount of reward Tokens
     */
    function withdrawRewardTokens(address _admin, uint256 _amount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(rewardTokenAddress != address(0x0), "Zero address of reward token");
        _safeTransfer(rewardTokenAddress, _admin, _amount);
        emit AdminWithdraw(_admin, _amount);
    }

    /** @notice Supply "amount" for reward
     * @dev  emit `Supply` event.
     * @param _user User address
     * @param _amount Amount that user supply
     */
    function _supply(address _user, uint256 _amount) internal {
        
        require(_amount > 0, "Not enough to deposite");
        update();
        User storage _userStruct = users[_user];

        _userStruct.amountSupplied += _amount;
        _userStruct.missedReward += _amount * tokenPerSupply;
        totalAmountSupplied += _amount;

        emit Supply(_user, _amount);
    }

    /** @notice Withdraw tokens.
     * @dev  emit `Withdraw` event.
     * @param _user User address
     * @param _amount Amount which user want to `withdraw`.
     */
    function _withdraw(address _user, uint256 _amount) internal {
        User storage _userStruct = users[_user];
        require(_amount > 0, "Amount can not be zero");

        update();
        _claim();

        // When withdraw from lending more than supply or return more than borrow. Its normal situation for lending because fees for using lending
        if (_amount >= _userStruct.amountSupplied) {
            _amount = _userStruct.amountSupplied;
        }

        _userStruct.amountSupplied -= _amount;
        _userStruct.missedReward = tokenPerSupply * _userStruct.amountSupplied;
        totalAmountSupplied -= _amount;

        emit Withdraw(_user, _amount, totalAmountSupplied);
    }

    /** @notice Claim reward tokens.
     * @dev transfer all available reward tokens from contract to user address.
     * @dev emit `Claim` event.
     */
    function claim() external nonReentrant {
        update();
        require(users[msg.sender].amountSupplied > 0, "Nothing to claim");
        _claim();
    }

    /** @notice Set parameters of rewarding by Admin.
     * @dev  emit `setParameters` event.
     * @param _rewardPerEpoch New amount reward tokens which will available in epoch.
     * @param _epochDuration New duration of epoch.
     * @param _rewardDuration Min amount of time for receive reward.
     */
    function setParameters(
        uint256 _rewardPerEpoch,
        uint256 _epochDuration,
        uint256 _rewardDuration
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        update();
        require(_epochDuration >= _rewardDuration, "Incorrect parametres");

        epochDuration = _epochDuration;
        rewardPerEpoch = _rewardPerEpoch;
        rewardDuration = _rewardDuration;

        emit ParametersSet(
            _rewardPerEpoch,
            _epochDuration,
            _rewardDuration
        );
    }

    /** @notice Claim reward tokens.
     * @dev transfer all available reward tokens from contract to user address
     * @dev or transfer fee to contract balance
     * @dev emit `Claim` event.
     */
    function _claim() internal {
        uint256 amount = _availableReward(msg.sender);
        users[msg.sender].missedReward += amount * precision;

        _safeTransfer(rewardTokenAddress, msg.sender, amount);

        emit Claim(msg.sender, amount);
    }

    /** @notice Update reward variable.
     * @dev calculate and set new tokenPerSupply from reward parametres
    */
    function update() private {
        uint256 amountOfDuration = (block.timestamp - lastTimeChangedTps) /
            rewardDuration;

        lastTimeChangedTps += rewardDuration * amountOfDuration;

        if (totalAmountSupplied > 0) {
            tokenPerSupply =
                tokenPerSupply +
                (((rewardPerEpoch * rewardDuration) * precision) /
                    (totalAmountSupplied * epochDuration)) *
                amountOfDuration;
        }
    }

    /** @notice Return amount of tokens, which `user` can claim.
     * @param _user Address of user.
     */
    function _availableReward(address _user)
        public
        view
        returns (uint256 amount)
    {
        if (users[_user].amountSupplied == 0) {
            return 0;
        }

        uint256 amountOfDuration = (block.timestamp - lastTimeChangedTps) /
            rewardDuration;

        uint256 currentTPS = tokenPerSupply +
            ((rewardPerEpoch * rewardDuration * precision) /
                (totalAmountSupplied * epochDuration)) *
            amountOfDuration;

        amount =
            ((currentTPS * users[_user].amountSupplied) -
                users[_user].missedReward) /
            precision;
    }

    /** @notice Return amount supplied by user.
     * @param _user Address of user.
     */
    function getUserAmountSupplied(address _user) external view returns (uint256) {
        return users[_user].amountSupplied;
    }

    /** @notice Return array contained `userInfo` .
     * @param _users Address's of users.
     */
    function getUserInfo(address[] memory _users)
        external
        view
        returns (User[] memory userList)
    {
        userList = new User[](_users.length);
        for (uint256 i; i < _users.length; i++) {
            userList[i] = User({
                amountSupplied: users[_users[i]].amountSupplied,
                missedReward: (users[_users[i]].missedReward / precision)
            });
        }

        return (userList);
    }

    /** @notice Return information about rewarding.
     */
    function getData()
        external
        view onlyRole(DEFAULT_ADMIN_ROLE)
        returns (
            address _rewardTokenAddress,
            uint256 _rewardPerEpoch,
            uint256 _epochDuration,
            uint256 _rewardDuration,
            uint256 _totalAmountSupplied,
            uint256 _tokenPerSupply
        )
    {
        return (
            rewardTokenAddress,
            rewardPerEpoch,
            epochDuration,
            rewardDuration,
            totalAmountSupplied,
            (tokenPerSupply / precision)
        );
    }

    function supply(address _user, uint256 _amount) external nonReentrant onlyRole(LENDING_CONTRACTS_ROLE) {
        _supply(_user, _amount);
    }

    function withdraw(address _user, uint256 _amount) external nonReentrant onlyRole(LENDING_CONTRACTS_ROLE) {
        _withdraw(_user, _amount);
    }

    function borrow(address _user, uint256 _amount) external nonReentrant onlyRole(LENDING_CONTRACTS_ROLE) {
        _supply(_user, _amount);
    }

    function repay(address _user, uint256 _amount) external nonReentrant onlyRole(LENDING_CONTRACTS_ROLE) {
        _withdraw(_user, _amount);
    }
    
}