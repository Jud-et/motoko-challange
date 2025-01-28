import List "mo:base/List";
import Principal "mo:base/Principal";

// Define the types for Auction system

type Item = {
  title : Text;
  description : Text;
  image : Blob;
};

type Bid = {
  price : Nat;
  time : Nat;
  originator : Principal;
};

type AuctionId = Nat;

type Auction = {
  id : AuctionId;
  item : Item;
  var bidHistory : List.List<Bid>;
  var remainingTime : Nat;
};

// Stable variables to persist data across upgrades
stable var auctions = List.nil<Auction>(); // List of all auctions
stable var idCounter = 0;  // Counter to generate unique Auction IDs

// Function to create a new auction and store it
public func newAuction(item : Item, duration : Nat) : async AuctionId {
  let auctionId = idCounter;
  idCounter += 1;  // Increment the auction ID counter
  
  // Create a new auction
  let newAuction : Auction = {
    id = auctionId;
    item = item;
    var bidHistory = List.nil<Bid>();  // Empty bid history initially
    var remainingTime = duration;  // Auction duration
  };

  // Store the auction in the stable variable
  auctions := List.push(newAuction, auctions);

  return auctionId;  // Return the new auction ID
};

// Function to retrieve the details of an auction by its ID
public query func getAuctionDetails(auctionId : AuctionId) : async ?Auction {
  let result = List.find<Auction>(auctions, func (auction) = auction.id == auctionId);
  
  switch (result) {
    case null {
      return null;  // Auction not found
    };
    case (?auction) {
      return ?auction;  // Return the auction details
    };
  }
};

// Function to retrieve all active auctions (those with remainingTime > 0)
public query func getActiveAuctions() : async [Auction] {
  // Filter auctions to include only those that are still active (remainingTime > 0)
  let activeAuctions = List.filter(auctions, func (auction) : Bool {
    auction.remainingTime > 0;  // Only include active auctions
  });

  return List.toArray(activeAuctions);  // Convert to array for easier handling in the frontend
};
