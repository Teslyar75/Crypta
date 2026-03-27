// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

contract Forum{
    error NotOwner(address from);
    error NotAuthorized(address from);
    error PostNotFound(uint idx);

    event PostCreated(address indexed author, uint indexed postId, uint created_at);
    event PostRemoved(address indexed author, uint indexed postId, uint removed_at);
    event PostsCleared(uint indexed timestamp, uint post_count);
    event PostLiked(address indexed user, uint indexed postId, uint likeCount);
    event PostUnliked(address indexed user, uint indexed postId, uint likeCount);

    struct Post{
        string message;
        address author;
        uint created_at;
        uint like;
        bool exists;
    }

    address owner;
    Post[] posts;
    mapping(uint => mapping(address => bool)) public hasLiked;

    constructor(){
        owner = msg.sender;
    }

    function clear_posts() external {
        require(owner == msg.sender, NotOwner(msg.sender));
        uint posts_q = posts.length;
        emit PostsCleared(block.timestamp, posts_q);
        delete posts;
    }

    function create_post(string calldata message) external{
        require(bytes(message).length > 0, "Message cannot be empty");
        posts.push(
            Post(
                message,
                msg.sender,
                block.timestamp,
                0,
                true
            )
        );
        emit PostCreated(msg.sender, posts.length - 1, block.timestamp);
    }

    function remove_post(uint idx) external {
        require(idx < posts.length, PostNotFound(idx));
        require(posts[idx].exists, PostNotFound(idx));
        require(posts[idx].author == msg.sender, NotAuthorized(msg.sender));
        posts[idx].exists = false;
        emit PostRemoved(msg.sender, idx, block.timestamp);
    }

    function like_post(uint idx) external {
        require(idx < posts.length, PostNotFound(idx));
        require(posts[idx].exists, PostNotFound(idx));
        require(!hasLiked[idx][msg.sender], "Already liked");
        hasLiked[idx][msg.sender] = true;
        posts[idx].like++;
        emit PostLiked(msg.sender, idx, posts[idx].like);
    }

    function unlike_post(uint idx) external {
        require(idx < posts.length, PostNotFound(idx));
        require(posts[idx].exists, PostNotFound(idx));
        require(hasLiked[idx][msg.sender], "Not liked yet");
        hasLiked[idx][msg.sender] = false;
        posts[idx].like--;
        emit PostUnliked(msg.sender, idx, posts[idx].like);
    }

    function get_posts() external view returns(Post[] memory){
        return posts;
    }

    function get_post(uint idx) external view returns(Post memory){
        require(idx < posts.length, PostNotFound(idx));
        return posts[idx];
    }

    function has_liked(uint idx) external view returns(bool){
        return hasLiked[idx][msg.sender];
    }
}