import List "mo:base/List";
import Principal "mo:base/Principal";
import Timer "mo:base/Timer";

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
  var isClosed : Bool;  // To track if the auction is closed
  var winningBid : ?Bid;  // Optional field to store the winning bid
  var reservePrice : Nat;  // Reserve price set by the auction creator
  var isSold : Bool;  // To track if the item is sold or not
};

// Stable variables to persist data across upgrades
stable var auctions = List.nil<Auction>(); // List of all auctions
stable var idCounter = 0;  // Counter to generate unique Auction IDs

// Function to create a new auction and store it
public func newAuction(item : Item, duration : Nat, reservePrice : Nat) : async AuctionId {
  let auctionId = idCounter;
  idCounter += 1;  // Increment the auction ID counter
  
  // Create a new auction with a reserve price
  let newAuction : Auction = {
    id = auctionId;
    item = item;
    var bidHistory = List.nil<Bid>();  // Empty bid history initially
    var remainingTime = duration;  // Auction duration
    var isClosed = false;  // Initially not closed
    var winningBid = null;  // No winning bid yet
    var reservePrice = reservePrice;  // Set the reserve price
    var isSold = false;  // Initially not sold
  };

  // Store the auction in the stable variable
  auctions := List.push(newAuction, auctions);

  // Start a periodic timer to check auction status every 10 seconds
  ignore Timer.setTimer(#seconds(10), func () : <system> async () {
    await checkAndCloseAuctions();
  });

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
  let activeAuctions = List.filter(auctions, func (auction) : Bool {
    auction.remainingTime > 0 && !auction.isClosed;  // Only active auctions
  });

  return List.toArray(activeAuctions);  // Convert to array for easier handling in frontend
};

// Periodic function to check and close auctions when their time expires
func checkAndCloseAuctions() : async () {
  // Iterate through each auction to check if it should be closed
  for (auction in auctions) {
    if (auction.remainingTime == 0 && !auction.isClosed) {
      // Determine the winning bid
      let highestBidOption = List.headOption(auction.bidHistory);
      switch (highestBidOption) {
        case null {
          auction.winningBid := null;  // No bids, auction failed
        };
        case (?bid) {
          auction.winningBid := ?bid;  // Set the highest bid as the winning bid
        };
      }

      // Check if the winning bid meets the reserve price
      if (auction.winningBid == null || auction.winningBid.price < auction.reservePrice) {
        auction.isSold := false;  // Item is not sold if the bid is lower than the reserve price
      } else {
        auction.isSold := true;  // Item is sold if the bid meets or exceeds the reserve price
      }

      // Mark the auction as closed
      auction.isClosed := true;

      // Optionally, you can log or perform other actions for the auction closing:
      Debug.print("Auction " # Nat.toText(auction.id) # " has closed. Winning bid: " # debug_show(auction.winningBid) # " Sold: " # Bool.toText(auction.isSold));
    } else if (auction.remainingTime > 0) {
      // Decrease the remaining time for active auctions
      auction.remainingTime := auction.remainingTime - 10;  // Decrease by 10 seconds
    }
  }

  // After checking all auctions, restart the timer to check again after 10 seconds
  ignore Timer.setTimer(#seconds(10), func () : <system> async () {
    await checkAndCloseAuctions();
  });
};
