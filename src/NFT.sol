// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC721Receiver} from "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {ERC721Utils} from "../lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Utils.sol";
import {IERC165} from "../lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {IERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {VRFConsumerBaseV2Plus} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";



struct RequestStatus {
        bool fulfilled;
        bool exists;
        uint256[] randomWords;
    }

    struct TokenMetadata {
        string collectionName;
        string symbol;
        uint256 tokenId;
        Rarity rarity;
        uint256 rarityNumber;
    }

    enum Rarity {
        Common,
        Uncommon,
        Rare,
        Epic,
        Legendary
    }


contract NFT is IERC721, IERC721Receiver, VRFConsumerBaseV2Plus {
    string private collectionName;
    string private _symbol;
    uint256 private mintPrice;
    uint256 public supply;
    uint256 public nextTokenId;
    uint256 public lastRequestId;
    uint32 public numWords = 1;
    uint256[] public requestList;
    address public contractOwner;
    bool private locked;
   

    

    bytes32 private keyHash =
        0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint256 private subId;
    uint16 private requestConfirmations = 3;
    uint32 callbackGasLimit = 250000;
    address private vrfCoordinator;

    mapping(address => uint256) public balance;
    mapping(uint256 => address) public tokenIdOwner;
    mapping(uint256 => address) public addressApproved;
    mapping(address => mapping(address => bool)) public operatorApproved;
    mapping(uint256 => uint256) public requestToTokenId;
    mapping(uint256 => address) public requestToOwner;
    mapping(uint256 => TokenMetadata) public tokenIdMetadata;

    

    
    mapping(uint256 => RequestStatus) public requestStatus;

    constructor(
        string memory _collectionName,
        string memory __symbol,
        uint256 _mintPrice,
        uint256 _supply,
        address _vrfCoordinator,
        uint256 _subId
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        require(
            _vrfCoordinator != address(0),
            "Invalid vrf coordinator address"
        );
        require(_supply > 0, "Invalid supply");
        require(_mintPrice > 0.0000001 ether, "Increase price per NFT");
        collectionName = _collectionName;
        _symbol = __symbol;
        mintPrice = _mintPrice;
        supply = _supply;
        vrfCoordinator = _vrfCoordinator;
        subId = _subId;
        contractOwner = msg.sender;
    }

    event RequestSent(uint256 indexed requestId, uint32 numWords);
    event RequestFulfilled(uint256 indexed requestId, uint256[] randomWords, uint256 rarityNumber);

    modifier nonReentrant() {
        require(!locked, "Reentrancy detected");
        locked = true;
        _;
        locked = false;
    }

    function totalSupply() external view returns (uint256) {
        return supply;
    }

    function name() public view returns (string memory) {
        return collectionName;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function getTokenIdMetadata(
        uint256 tokenId
    ) public view returns (TokenMetadata memory) {
        return tokenIdMetadata[tokenId];
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function withdrawFunds(uint256 amount) external nonReentrant {
        require(
            getContractBalance() >= amount,
            "Amount requested exceed contract balance"
        );
        require(msg.sender == contractOwner, "Contract owner only");
        (bool result, ) = payable(contractOwner).call{value: amount}("");
        require(result, "Transaction Failed");
    }

    function requestRandomNumber(
        bool enableNativePayment
    ) internal returns (uint256) {
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: subId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({
                        nativePayment: enableNativePayment
                    })
                )
            })
        );
        requestStatus[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        requestList.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function mint() external payable nonReentrant {
        require(msg.value >= mintPrice, "Funds insufficient");
        require(supply >= nextTokenId + 1, "No more NFT available for minting");
        requestRandomNumber(false);
        requestToTokenId[lastRequestId] = nextTokenId + 1;
        requestToOwner[lastRequestId] = msg.sender;
        if (msg.value > mintPrice) {
            (bool success, ) = payable(msg.sender).call{
                value: msg.value - mintPrice
            }("");
            require(success, "Refound failed");
        }
    }

    function getRequestStatus(
        uint256 requestId
    ) public view returns (RequestStatus memory) {
        return requestStatus[requestId];
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] calldata _randomWords
    ) internal override {
        require(requestStatus[_requestId].exists, "request not found");
        requestStatus[_requestId].fulfilled = true;
        requestStatus[_requestId].randomWords = _randomWords;
        uint256 rarityNumber = _randomWords[0] % 21;
        uint256 tokenId = requestToTokenId[_requestId];
        if (rarityNumber < 11 && rarityNumber > 0) tokenIdMetadata[tokenId].rarity = Rarity.Common;
        else if (rarityNumber < 15)
            tokenIdMetadata[tokenId].rarity = Rarity.Uncommon;
        else if (rarityNumber < 18)
            tokenIdMetadata[tokenId].rarity = Rarity.Rare;
        else if (rarityNumber < 20)
            tokenIdMetadata[tokenId].rarity = Rarity.Epic;
        else tokenIdMetadata[tokenId].rarity = Rarity.Legendary;
        address owner = requestToOwner[_requestId];
        tokenIdOwner[tokenId] = owner;
        balance[tokenIdOwner[tokenId]]++;
        tokenIdMetadata[tokenId].tokenId = tokenId;
        tokenIdMetadata[tokenId].symbol = _symbol;
        tokenIdMetadata[tokenId].collectionName = collectionName;
        tokenIdMetadata[tokenId].rarityNumber = rarityNumber;
        requestStatus[_requestId].exists = false;
        nextTokenId = tokenId;
        emit Transfer(address(0), owner, tokenId);
        emit RequestFulfilled(_requestId, _randomWords, rarityNumber);
    }

    function balanceOf(address owner) external view returns (uint256) {
        require(owner != address(0), "Invalid address");
        return balance[owner];
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        require(tokenId <= nextTokenId, "Token Id requested not mintend yet");
        return tokenIdOwner[tokenId];
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        require(
            from != address(0) && to != address(0),
            "Invalid transfer address"
        );
        require(
            tokenIdOwner[tokenId] == from,
            "Address received is not the token owner"
        );
        require(
            tokenIdOwner[tokenId] == msg.sender ||
                addressApproved[tokenId] == msg.sender ||
                operatorApproved[tokenIdOwner[tokenId]][msg.sender] == true,
            "Caller is not owner or approved"
        );
        require(tokenIdOwner[tokenId] != address(0), "Token not minted yet");

        if (addressApproved[tokenId] != address(0)) {
            addressApproved[tokenId] = address(0);
            emit Approval(tokenIdOwner[tokenId], address(0), tokenId);
        }
        require(balance[from] > 0, "Sender address has no token");
        tokenIdOwner[tokenId] = to;
        balance[from] -= 1;
        balance[to] += 1;
        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual {
        require(
            from != address(0) && to != address(0),
            "Invalid transfer address"
        );
        transferFrom(from, to, tokenId);
        ERC721Utils.checkOnERC721Received(msg.sender, from, to, tokenId, data);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    function approve(address to, uint256 tokenId) external {
        address owner = tokenIdOwner[tokenId];
        require(owner != address(0), "Token doesn't exist");
        require(owner == msg.sender, "Caller is not owner");
        require(to != owner, "Approval to current owner");

        addressApproved[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approval) external {
        require(
            operator != address(0) && operator != msg.sender,
            "Choose a valid address"
        );

        operatorApproved[msg.sender][operator] = approval;
        emit ApprovalForAll(
            msg.sender,
            operator,
            operatorApproved[msg.sender][operator]
        );
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        require(tokenIdOwner[tokenId] != address(0), "Token doesn't exist");
        return addressApproved[tokenId];
    }

    function isApprovedForAll(
        address owner,
        address operator
    ) external view returns (bool) {
        return operatorApproved[owner][operator];
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId;
    }
}
