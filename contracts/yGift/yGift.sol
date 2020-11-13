// SPDX-License-Identifier: MIT

pragma solidity ^0.6.4;

import "../erc721/ERC721.sol";
import "../erc20/IERC20.sol";
import "../utils/SafeMath.sol";

library SafeERC20 {
	using SafeMath for uint256;
	using Address for address;

	function safeTransfer(IERC20 token, address to, uint256 value) internal {
		callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
	}

	function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
		callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
	}

	function safeApprove(IERC20 token, address spender, uint256 value) internal {
		require((value == 0) || (token.allowance(address(this), spender) == 0),
			"SafeERC20: approve from non-zero to non-zero allowance"
		);
		callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
	}
	function callOptionalReturn(IERC20 token, bytes memory data) private {
		require(address(token).isContract(), "SafeERC20: call to non-contract");

		// solhint-disable-next-line avoid-low-level-calls
		(bool success, bytes memory returndata) = address(token).call(data);
		require(success, "SafeERC20: low-level call failed");

		if (returndata.length > 0) { // Return data is optional
			// solhint-disable-next-line max-line-length
			require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
		}
	}
}

contract yGift is ERC721("yearn Gift NFT", "yGIFT") {
	using SafeERC20 for IERC20;
	using SafeMath for uint;

	struct Gift {
		address	token;
		string name;
		string message;
		string url;
		uint amount;
		uint start;
		uint duration;
	}

	Gift[] public gifts;

	event GiftMinted(address indexed from, address indexed to, uint indexed tokenId, uint unlocksAt);
	event Tip(address indexed tipper, uint indexed tokenId, address token, uint amount, string message);
	event Collected(address indexed collecter, uint indexed tokenId, address token, uint amount);

	/**
	 * @dev Mints a new Gift NFT and places it into the contract address for future collection
	 * _to: recipient of the gift
	 * _token: token address of the token to be gifted
	 * _amount: amount of _token to be gifted
	 * _name: name of the gift
	 * _msg: Tip message given by the original minter
	 * _url: URL link for the image attached to the nft
	 * _start: the amount of time the gift  will be locked until the recipient can collect it 
	 * _duration: duration over which the amount linearly becomes available
	 *
	 * requirement: only a whitelisted minter can call this function
	 *
	 * Emits a {Tip} event.
	 */
	function mint(
		address _to,
		address _token,
		uint _amount,
		string calldata _name,
		string calldata _msg,
		string calldata _url,
		uint _start,
		uint _duration)
	external {
		uint _id = gifts.length;
		Gift memory gift = Gift({
			token: _token,
			name: _name,
			message: _msg,
			url: _url,
			amount: _amount,
			start: _start,
			duration: _duration,
		});
		gifts.push(gift);
		_safeMint(_to, _id);
		IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
		emit GiftMinted(msg.sender, _to, _id, _start);
		emit Tip(msg.sender, _id, _token, _amount, _msg);
	}

	/**
	 * @dev Tip some tokens to Gift NFT 
	 * _tokenId: gift in which the function caller would like to tip
	 * _amount: amount of _token to be gifted
	 * _msg: Tip message given by the original minter
	 *
	 * Emits a {Tip} event.
	 */
	function tip(uint _tokenId, uint _amount, string calldata _msg) external {
		require(_tokenId < gifts.length, "yGift: Token ID does not exist.");
		Gift storage gift = gifts[_tokenId];
		gift.amount = gift.amount.add(_amount);
		IERC20(gift.token).safeTransferFrom(msg.sender, address(this), _amount);
		emit Tip(msg.sender, _tokenId, gift.token, _amount, _msg);
	}

	function min(uint a, uint b) internal pure return (uint) {
		return a < b ? a : b;
	}
	
	function available(uint amount, uint start, uint duration) public view returns (uint) {
		if (block.timestamp < start) return 0;
		if (duration == 0) return amount;
		return amount * min(block.timestamp - start, duration) / duration;
	}

	/**
	 * @dev Allows the gift recipient to collect their tokens
	 * _tokenId: gift in which the function caller would like to tip
	 * _amount: amount of tokens the gift owner would like to collect
	 *
	 * requirement: caller must own the gift recipient && gift must have been redeemed
	 */
	function collect(uint _tokenId, uint _amount) public {
		require(_isApprovedOrOwner(msg.sender, _tokenId), "yGift: You are not the NFT owner.");
		
		Gift storage gift = gifts[_tokenId];
		
		require(gift.start > block.timestamp, "yGift: Rewards still vesting");
		uint _available = available(gift.amount, gift.start, gift.duration);
		if (_amount < _available) _amount = _available;
		require(_amount > 0, "yGift: insufficient amount");

		gift.amount = gift.amount.sub(_amount);
		IERC20(gift.token).safeTransfer(msg.sender, _amount);
		emit Collected(msg.sender, _tokenId, gift.token, _amount);
	}

	function onERC721Received(address _operator, address _from, uint _tokenId, bytes calldata _data) external view returns (bytes4) {
		require(msg.sender == address(this), "yGift: Cannot receive other NFTs");
		return yGift.onERC721Received.selector;
	}
}
