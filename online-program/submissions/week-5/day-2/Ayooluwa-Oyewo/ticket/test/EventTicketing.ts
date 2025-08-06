import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre from "hardhat";

describe("EventTicketing", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployEventTicketingFixture() {
    const [owner, eventOwner, eventTicketBuyer, anotherEventTicketBuyer] =
      await hre.ethers.getSigners();

    const EventTicketing = await hre.ethers.getContractFactory(
      "EventTicketing"
    );
    const eventTicketing = await EventTicketing.deploy();

    return {
      eventTicketing,
      owner,
      anotherEventTicketBuyer,
      eventOwner,
      eventTicketBuyer,
    };
  }

  describe("Deployment", function () {
    it("Should deploy the contract and set the right owner", async function () {
      const { eventTicketing, owner } = await deployEventTicketingFixture();

      expect(await eventTicketing.superAdmin()).to.equal(owner.address);
      expect(await eventTicketing.nextEventId()).to.equal(0);
      expect(await eventTicketing.nextTicketTypeId()).to.equal(0);
      expect(await eventTicketing.nextTokenId()).to.equal(0);
    });
  });

  describe("Add Admin", function () {
    it("Should allow the super admin to add an admin", async function () {
      const { eventTicketing, owner, eventOwner } =
        await deployEventTicketingFixture();

      await expect(eventTicketing.connect(owner).addAdmin(eventOwner.address))
        .to.emit(eventTicketing, "AdminAdded")
        .withArgs(eventOwner.address);

      expect(await eventTicketing.admins(eventOwner.address)).to.equal(true);
    });

    it("Should revert if a non-super admin tries to add an admin", async function () {
      const { eventTicketing, eventOwner, anotherEventTicketBuyer } =
        await deployEventTicketingFixture();

      await expect(
        eventTicketing
          .connect(anotherEventTicketBuyer)
          .addAdmin(eventOwner.address)
      ).to.be.revertedWithCustomError(eventTicketing, "NotSuperAdmin");
    });
  });

  describe("Remove Admin", function () {
    it("Should allow the super admin to remove an admin", async function () {
      const { eventTicketing, owner, eventOwner } =
        await deployEventTicketingFixture();

      // First, add the admin
      await eventTicketing.connect(owner).addAdmin(eventOwner.address);

      // Now remove the admin
      await expect(
        eventTicketing.connect(owner).removeAdmin(eventOwner.address)
      )
        .to.emit(eventTicketing, "AdminRemoved")
        .withArgs(eventOwner.address);

      expect(await eventTicketing.admins(eventOwner.address)).to.equal(false);
    });

    it("Should revert if a non-super admin tries to remove an admin", async function () {
      const { eventTicketing, eventOwner, anotherEventTicketBuyer } =
        await deployEventTicketingFixture();

      await expect(
        eventTicketing
          .connect(anotherEventTicketBuyer)
          .removeAdmin(eventOwner.address)
      ).to.be.revertedWithCustomError(eventTicketing, "NotSuperAdmin");
    });
  });
  describe("Create Event", function () {
    it("Should create an event with valid details", async function () {
      const { eventTicketing, eventOwner } =
        await deployEventTicketingFixture();

      const title = "Concert";
      const imageUrl = "https://example.com/image.jpg";
      const location = "Stadium";
      const description = "A great concert";
      const eventDate = Math.floor(Date.now() / 1000) + 86400; // 1 day in the future

      await expect(
        eventTicketing
          .connect(eventOwner)
          .createEvent(title, imageUrl, location, description, eventDate)
      )
        .to.emit(eventTicketing, "EventCreated")
        .withArgs(0, title);

      const eventDetails = await eventTicketing.events(0);
      expect(eventDetails.title).to.equal(title);
      expect(eventDetails.imageUrl).to.equal(imageUrl);
      expect(eventDetails.location).to.equal(location);
      expect(eventDetails.description).to.equal(description);
      expect(eventDetails.eventDate).to.equal(eventDate);
      expect(eventDetails.organizer).to.equal(eventOwner.address);
    });

    it("Should revert if any event detail is empty", async function () {
      const { eventTicketing, eventOwner } =
        await deployEventTicketingFixture();
      const title = "";
      const imageUrl = "https://example.com/image.jpg";
      const location = "Stadium";
      const description = "A great concert";
      const eventDate = Math.floor(Date.now() / 1000) + 86400; // 1 day in the future

      await expect(
        eventTicketing
          .connect(eventOwner)
          .createEvent(title, imageUrl, location, description, eventDate)
      )
        .to.be.revertedWithCustomError(eventTicketing, "InvalidInput")
        .withArgs("Event details cannot be empty");
    });

    it("Should revert if event date is in the past", async function () {
      const { eventTicketing, eventOwner } =
        await deployEventTicketingFixture();

      const title = "Past Event";
      const imageUrl = "https://example.com/image.jpg";
      const location = "Stadium";
      const description = "An event in the past";
      const eventDate = Math.floor(Date.now() / 1000) - 86400; // 1 day in the past

      await expect(
        eventTicketing
          .connect(eventOwner)
          .createEvent(title, imageUrl, location, description, eventDate)
      )
        .to.be.revertedWithCustomError(eventTicketing, "InvalidInput")
        .withArgs("Event date must be in the future");
    });
  });

  describe("Create Ticket Type", function () {
    it("Should create a ticket type with valid details", async function () {
      const { eventTicketing, eventOwner } =
        await deployEventTicketingFixture();
      // First, create an event to associate the ticket type with
      const title = "Concert";
      const imageUrl = "https://example.com/image.jpg";
      const location = "Stadium";
      const description = "A great concert";
      const eventDate = Math.floor(Date.now() / 1000) + 86400;
      await eventTicketing
        .connect(eventOwner)
        .createEvent(title, imageUrl, location, description, eventDate);
      const eventId = 0; // Assuming the first event has ID 0
      const name = "VIP Ticket";
      const price = hre.ethers.parseEther("1.0");
      const totalSupply = 100;
      const baseURI = "https://example.com/ticket/";

      await expect(
        eventTicketing
          .connect(eventOwner)
          .createTicketType(eventId, name, price, totalSupply, baseURI)
      )
        .to.emit(eventTicketing, "TicketTypeCreated")
        .withArgs(0, eventId, name);

      const ticketType = await eventTicketing.ticketTypes(0);
      expect(ticketType.name).to.equal(name);
      expect(ticketType.price).to.equal(price);
      expect(ticketType.totalSupply).to.equal(totalSupply);
      expect(ticketType.baseURI).to.equal(baseURI);
    });

    it("Should revert if ticket type details are invalid", async function () {
      const { eventTicketing, eventOwner } =
        await deployEventTicketingFixture();
      // First, create an event to associate the ticket type with
      const title = "Concert";
      const imageUrl = "https://example.com/image.jpg";
      const location = "Stadium";
      const description = "A great concert";
      const eventDate = Math.floor(Date.now() / 1000) + 86400;
      await eventTicketing
        .connect(eventOwner)
        .createEvent(title, imageUrl, location, description, eventDate);
      const eventId = 0; // Assuming an event with ID 0 exists
      const name = "";
      const price = hre.ethers.parseEther("1.0");
      const totalSupply = 100;
      const baseURI = "https://example.com/ticket/";

      await expect(
        eventTicketing
          .connect(eventOwner)
          .createTicketType(eventId, name, price, totalSupply, baseURI)
      )
        .to.be.revertedWithCustomError(eventTicketing, "InvalidInput")
        .withArgs("Ticket type details cannot be empty");
    });

    it("Should revert if ticket type price is zero", async function () {
      const { eventTicketing, eventOwner } =
        await deployEventTicketingFixture();
      // First, create an event to associate the ticket type with
      const title = "Concert";
      const imageUrl = "https://example.com/image.jpg";
      const location = "Stadium";
      const description = "A great concert";
      const eventDate = Math.floor(Date.now() / 1000) + 86400;
      await eventTicketing
        .connect(eventOwner)
        .createEvent(title, imageUrl, location, description, eventDate);
      const eventId = 0; // Assuming an event with ID 0 exists
      const name = "Free Ticket";
      const price = hre.ethers.parseEther("0.0");
      const totalSupply = 100;
      const baseURI = "https://example.com/ticket/";

      await expect(
        eventTicketing
          .connect(eventOwner)
          .createTicketType(eventId, name, price, totalSupply, baseURI)
      )
        .to.be.revertedWithCustomError(eventTicketing, "InvalidInput")
        .withArgs("Ticket type price must be greater than zero");
    });

    it("Should revert if ticket type total supply is zero", async function () {
      const { eventTicketing, eventOwner } =
        await deployEventTicketingFixture();
      // First, create an event to associate the ticket type with
      const title = "Concert";
      const imageUrl = "https://example.com/image.jpg";
      const location = "Stadium";
      const description = "A great concert";
      const eventDate = Math.floor(Date.now() / 1000) + 86400;
      await eventTicketing
        .connect(eventOwner)
        .createEvent(title, imageUrl, location, description, eventDate);
      const eventId = 0; // Assuming an event with ID 0 exists
      const name = "Limited Ticket";
      const price = hre.ethers.parseEther("1.0");
      const totalSupply = 0;
      const baseURI = "https://example.com/ticket/";

      await expect(
        eventTicketing
          .connect(eventOwner)
          .createTicketType(eventId, name, price, totalSupply, baseURI)
      )
        .to.be.revertedWithCustomError(eventTicketing, "InvalidInput")
        .withArgs("Ticket type total supply must be greater than zero");
    });
    it("Should revert if event does not exist", async function () {
      const { eventTicketing, eventOwner } =
        await deployEventTicketingFixture();
      const eventId = 999; // Non-existent event ID
      const name = "VIP Ticket";
      const price = hre.ethers.parseEther("1.0");
      const totalSupply = 100;
      const baseURI = "https://example.com/ticket/";

      await expect(
        eventTicketing
          .connect(eventOwner)
          .createTicketType(eventId, name, price, totalSupply, baseURI)
      )
        .to.be.revertedWithCustomError(eventTicketing, "InvalidInput")
        .withArgs("Event does not exist");
    });
    it("Should revert if the caller is not the event owner", async function () {
      const { eventTicketing, eventOwner, eventTicketBuyer } =
        await deployEventTicketingFixture();
      // First, create an event to associate the ticket type with
      const title = "Concert";
      const imageUrl = "https://example.com/image.jpg";
      const location = "Stadium";
      const description = "A great concert";
      const eventDate = Math.floor(Date.now() / 1000) + 86400;
      await eventTicketing
        .connect(eventOwner)
        .createEvent(title, imageUrl, location, description, eventDate);
      const eventId = 0; // Assuming an event with ID 0 exists
      const name = "VIP Ticket";
      const price = hre.ethers.parseEther("1.0");
      const totalSupply = 100;
      const baseURI = "https://example.com/ticket/";

      await expect(
        eventTicketing
          .connect(eventTicketBuyer)
          .createTicketType(eventId, name, price, totalSupply, baseURI)
      ).to.be.revertedWithCustomError(eventTicketing, "NotEventOwner");
    });
  });

  describe("Modify Event Status", function () {
    it("Should allow the event owner to modify event status", async function () {
      const { eventTicketing, eventOwner } =
        await deployEventTicketingFixture();
      // First, create an event
      const title = "Concert";
      const imageUrl = "https://example.com/image.jpg";
      const location = "Stadium";
      const description = "A great concert";
      const eventDate = Math.floor(Date.now() / 1000) + 86400;
      await eventTicketing
        .connect(eventOwner)
        .createEvent(title, imageUrl, location, description, eventDate);
      const eventId = 0; // Assuming the first event has ID 0

      // Modify the event status to inactive
      await expect(
        eventTicketing.connect(eventOwner).modifyEventStatus(eventId, false)
      )
        .to.emit(eventTicketing, "EventStatusModified")
        .withArgs(eventId, false);

      // Check the event status
      const eventDetails = await eventTicketing.events(eventId);
      expect(eventDetails.isActive).to.equal(false);
    });

    it("Should revert if the caller is not the event owner", async function () {
      const { eventTicketing, eventOwner, eventTicketBuyer } =
        await deployEventTicketingFixture();
      // First, create an event
      const title = "Concert";
      const imageUrl = "https://example.com/image.jpg";
      const location = "Stadium";
      const description = "A great concert";
      const eventDate = Math.floor(Date.now() / 1000) + 86400;
      await eventTicketing
        .connect(eventOwner)
        .createEvent(title, imageUrl, location, description, eventDate);
      const eventId = 0; // Assuming the first event has ID 0

      // Attempt to modify the event status as a non-owner
      await expect(
        eventTicketing
          .connect(eventTicketBuyer)
          .modifyEventStatus(eventId, false)
      ).to.be.revertedWithCustomError(eventTicketing, "NotEventOwner");
    });

    it("Should revert if the event does not exist", async function () {
      const { eventTicketing, eventOwner } =
        await deployEventTicketingFixture();
      const nonExistentEventId = 999;
      // Attempt to modify the status of a non-existent event
      await expect(
        eventTicketing
          .connect(eventOwner)
          .modifyEventStatus(nonExistentEventId, false)
      )
        .to.be.revertedWithCustomError(eventTicketing, "InvalidInput")
        .withArgs("Event does not exist");
    });
  });

  describe("Update Event Details", function () {
    it("Should allow the event owner to update event details", async function () {
      const { eventTicketing, eventOwner } =
        await deployEventTicketingFixture();
      // First, create an event
      const title = "Concert";
      const imageUrl = "https://example.com/image.jpg";
      const location = "Stadium";
      const description = "A great concert";
      const eventDate = Math.floor(Date.now() / 1000) + 86400;
      await eventTicketing
        .connect(eventOwner)
        .createEvent(title, imageUrl, location, description, eventDate);
      const eventId = 0; // Assuming the first event has ID 0
      // Update the event details
      const newTitle = "Updated Concert";
      const newImageUrl = "https://example.com/updated_image.jpg";
      const newLocation = "Updated Stadium";
      const newDescription = "An even greater concert";
      const newEventDate = Math.floor(Date.now() / 1000) + 172;
      800; // 2 days in the future
      await expect(
        eventTicketing
          .connect(eventOwner)
          .updateEvent(
            eventId,
            newTitle,
            newImageUrl,
            newLocation,
            newDescription,
            newEventDate
          )
      )
        .to.emit(eventTicketing, "EventUpdated")
        .withArgs(eventId, newTitle);

      // Check the updated event details
      const eventDetails = await eventTicketing.events(eventId);
      expect(eventDetails.title).to.equal(newTitle);
      expect(eventDetails.imageUrl).to.equal(newImageUrl);
      expect(eventDetails.location).to.equal(newLocation);
      expect(eventDetails.description).to.equal(newDescription);
      expect(eventDetails.eventDate).to.equal(newEventDate);
    });
    it("Should revert if the caller is not the event owner", async function () {
      const { eventTicketing, eventOwner, eventTicketBuyer } =
        await deployEventTicketingFixture();
      // First, create an event
      const title = "Concert";
      const imageUrl = "https://example.com/image.jpg";
      const location = "Stadium";
      const description = "A great concert";
      const eventDate = Math.floor(Date.now() / 1000) + 86400;
      await eventTicketing
        .connect(eventOwner)
        .createEvent(title, imageUrl, location, description, eventDate);
      const eventId = 0; // Assuming the first event has ID 0

      // Attempt to update the event details as a non-owner
      await expect(
        eventTicketing
          .connect(eventTicketBuyer)
          .updateEvent(
            eventId,
            title,
            imageUrl,
            location,
            description,
            eventDate
          )
      ).to.be.revertedWithCustomError(eventTicketing, "NotEventOwner");
    });

    it("Should revert if the event does not exist", async function () {
      const { eventTicketing, eventOwner } =
        await deployEventTicketingFixture();
      const nonExistentEventId = 999;
      const title = "Concert";
      const imageUrl = "https://example.com/image.jpg";
      const location = "Stadium";
      const description = "A great concert";
      const eventDate = Math.floor(Date.now() / 1000) + 86400;

      // Attempt to update the details of a non-existent event
      await expect(
        eventTicketing
          .connect(eventOwner)
          .updateEvent(
            nonExistentEventId,
            title,
            imageUrl,
            location,
            description,
            eventDate
          )
      )
        .to.be.revertedWithCustomError(eventTicketing, "InvalidInput")
        .withArgs("Event does not exist");
    });
    it("Should revert if any event detail is empty", async function () {
      const { eventTicketing, eventOwner } =
        await deployEventTicketingFixture();
      // First, create an event
      const title = "Concert";
      const imageUrl = "https://example.com/image.jpg";
      const location = "Stadium";
      const description = "A great concert";
      const eventDate = Math.floor(Date.now() / 1000) + 86400;
      await eventTicketing
        .connect(eventOwner)
        .createEvent(title, imageUrl, location, description, eventDate);
      const eventId = 0; // Assuming the first event has ID 0

      // Attempt to update the event with an empty title
      await expect(
        eventTicketing
          .connect(eventOwner)
          .updateEvent(eventId, "", imageUrl, location, description, eventDate)
      )
        .to.be.revertedWithCustomError(eventTicketing, "InvalidInput")
        .withArgs("Event details cannot be empty");
    });
  });

  describe("Mint Ticket", function () {
    it("Should allow users to mint tickets", async function () {
      const { eventTicketing, eventOwner, eventTicketBuyer } =
        await deployEventTicketingFixture();
      // First, create an event and a ticket type
      const title = "Concert";
      const imageUrl = "https://example.com/image.jpg";
      const location = "Stadium";
      const description = "A great concert";
      const eventDate = Math.floor(Date.now() / 1000) + 86400;
      await eventTicketing
        .connect(eventOwner)
        .createEvent(title, imageUrl, location, description, eventDate);
      const eventId = 0; // Assuming the first event has ID 0
      const name = "VIP Ticket";
      const price = hre.ethers.parseEther("1.0");
      const totalSupply = 100;
      const baseURI = "https://example.com/ticket/";
      await eventTicketing
        .connect(eventOwner)
        .createTicketType(eventId, name, price, totalSupply, baseURI);

      await expect(
        eventTicketing.connect(eventTicketBuyer).mintTicket(0, { value: price })
      )
        .to.emit(eventTicketing, "TicketMinted")
        .withArgs(0, eventTicketBuyer.address); // We accept any value as `tokenId` arg

      // Check the buyer's balance and the ticket type's sold count
      expect(await eventTicketing.balanceOf(eventTicketBuyer.address)).to.equal(
        1
      );
      const ticketType = await eventTicketing.ticketTypes(0);
      expect(ticketType.minted).to.equal(1);
    });

    it("Should revert if event is sold out", async function () {
      const { eventTicketing, eventOwner, eventTicketBuyer } =
        await deployEventTicketingFixture();
      // First, create an event and a ticket type
      const title = "Concert";
      const imageUrl = "https://example.com/image.jpg";
      const location = "Stadium";
      const description = "A great concert";
      const eventDate = Math.floor(Date.now() / 1000) + 86400;
      await eventTicketing
        .connect(eventOwner)
        .createEvent(title, imageUrl, location, description, eventDate);
      const eventId = 0; // Assuming the first event has ID 0
      const name = "VIP Ticket";
      const price = hre.ethers.parseEther("1.0");
      const totalSupply = 1; // Set total supply to 1 for testing
      const baseURI = "https://example.com/ticket/";
      await eventTicketing
        .connect(eventOwner)
        .createTicketType(eventId, name, price, totalSupply, baseURI);
      // Mint the only available ticket
      await eventTicketing
        .connect(eventTicketBuyer)
        .mintTicket(0, { value: price });
      // Attempt to mint another ticket, which should fail
      await expect(
        eventTicketing.connect(eventTicketBuyer).mintTicket(0, { value: price })
      ).to.be.revertedWithCustomError(eventTicketing, "SoldOut");
    });

    it("Should revert if invalid ticket price is sent", async function () {
      const { eventTicketing, eventOwner, eventTicketBuyer } =
        await deployEventTicketingFixture();
      // First, create an event and a ticket type
      const title = "Concert";
      const imageUrl = "https://example.com/image.jpg";
      const location = "Stadium";
      const description = "A great concert";
      const eventDate = Math.floor(Date.now() / 1000) + 86400;
      await eventTicketing
        .connect(eventOwner)
        .createEvent(title, imageUrl, location, description, eventDate);
      const eventId = 0; // Assuming the first event has ID 0
      const name = "VIP Ticket";
      const price = hre.ethers.parseEther("1.0");
      const totalSupply = 100;
      const baseURI = "https://example.com/ticket/";
      await eventTicketing
        .connect(eventOwner)
        .createTicketType(eventId, name, price, totalSupply, baseURI);
      // Attempt to mint a ticket with an incorrect price
      await expect(
        eventTicketing
          .connect(eventTicketBuyer)
          .mintTicket(0, { value: hre.ethers.parseEther("0.5") })
      ).to.be.revertedWithCustomError(eventTicketing, "InvalidPayment");
    });
  });
  describe("Redeem Ticket", function () {
    it("Should allow ticket owners to redeem their tickets", async function () {
      const { eventTicketing, eventOwner, eventTicketBuyer } =
        await deployEventTicketingFixture();
      // First, create an event and a ticket type
      const title = "Concert";
      const imageUrl = "https://example.com/image.jpg";
      const location = "Stadium";
      const description = "A great concert";
      const eventDate = Math.floor(Date.now() / 1000) + 86400;
      await eventTicketing
        .connect(eventOwner)
        .createEvent(title, imageUrl, location, description, eventDate);
      const eventId = 0; // Assuming the first event has ID 0
      const name = "VIP Ticket";
      const price = hre.ethers.parseEther("1.0");
      const totalSupply = 100;
      const baseURI = "https://example.com/ticket/";
      await eventTicketing
        .connect(eventOwner)
        .createTicketType(eventId, name, price, totalSupply, baseURI);
      // Mint a ticket
      await eventTicketing
        .connect(eventTicketBuyer)
        .mintTicket(0, { value: price });
      // Redeem the ticket
      await expect(eventTicketing.connect(eventTicketBuyer).redeemTicket(0))
        .to.emit(eventTicketing, "TicketRedeemed")
        .withArgs(0, eventTicketBuyer.address);

      // Check that the ticket is marked as redeemed
      const ticket = await eventTicketing.tickets(0);
      expect(ticket.isRedeemed).to.equal(true);
    });

    it("Should revert if the ticket is not owned by the caller", async function () {
      const {
        eventTicketing,
        eventOwner,
        eventTicketBuyer,
        anotherEventTicketBuyer,
      } = await deployEventTicketingFixture();
      // First, create an event and a ticket type
      const title = "Concert";
      const imageUrl = "https://example.com/image.jpg";
      const location = "Stadium";
      const description = "A great concert";
      const eventDate = Math.floor(Date.now() / 1000) + 86400;
      await eventTicketing
        .connect(eventOwner)
        .createEvent(title, imageUrl, location, description, eventDate);
      const eventId = 0; // Assuming the first event has ID 0
      const name = "VIP Ticket";
      const price = hre.ethers.parseEther("1.0");
      const totalSupply = 100;
      const baseURI = "https://example.com/ticket/";
      await eventTicketing
        .connect(eventOwner)
        .createTicketType(eventId, name, price, totalSupply, baseURI);
      // Mint a ticket to the eventTicketBuyer
      await eventTicketing
        .connect(eventTicketBuyer)
        .mintTicket(0, { value: price });
      // Attempt to redeem the ticket as a different user
      await expect(
        eventTicketing.connect(anotherEventTicketBuyer).redeemTicket(0)
      ).to.be.revertedWithCustomError(eventTicketing, "NotTicketOwner");
    });
    it("Should revert if the ticket is already redeemed", async function () {
      const { eventTicketing, eventOwner, eventTicketBuyer } =
        await deployEventTicketingFixture();
      // First, create an event and a ticket type
      const title = "Concert";
      const imageUrl = "https://example.com/image.jpg";
      const location = "Stadium";
      const description = "A great concert";
      const eventDate = Math.floor(Date.now() / 1000) + 86400;
      await eventTicketing
        .connect(eventOwner)
        .createEvent(title, imageUrl, location, description, eventDate);
      const eventId = 0; // Assuming the first event has ID 0
      const name = "VIP Ticket";
      const price = hre.ethers.parseEther("1.0");
      const totalSupply = 100;
      const baseURI = "https://example.com/ticket/";
      await eventTicketing
        .connect(eventOwner)
        .createTicketType(eventId, name, price, totalSupply, baseURI);
      // Mint a ticket
      await eventTicketing
        .connect(eventTicketBuyer)
        .mintTicket(0, { value: price });
      // Redeem the ticket once
      await eventTicketing.connect(eventTicketBuyer).redeemTicket(0);
      // Attempt to redeem the same ticket again
      await expect(
        eventTicketing.connect(eventTicketBuyer).redeemTicket(0)
      ).to.be.revertedWithCustomError(eventTicketing, "AlreadyRedeemed");
    });
  });
});
