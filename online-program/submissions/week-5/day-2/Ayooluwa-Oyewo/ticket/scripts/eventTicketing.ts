import hre from "hardhat";

async function main() {
    const [owner, eventOwner, eventTicketBuyer, anotherEventTicketBuyer] = await hre.ethers.getSigners();

    console.log("Deploying EventTicketing contract...");
    console.log("Event Owner address:", eventOwner.address);

    // Deploy the EventTicketing contract
    const EventTicketing = await hre.ethers.getContractFactory("EventTicketing");
    const eventTicketing = await EventTicketing.deploy();
    await eventTicketing.waitForDeployment();

    const contractAddress = await eventTicketing.getAddress();
    console.log(`EventTicketing deployed to: ${contractAddress}`);
    
    // Verify deployment on network (uncomment for testnets/mainnet)
    if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
        console.log("Waiting for block confirmations...");
        await eventTicketing.deploymentTransaction()?.wait(6);
        
        try {
            await hre.run("verify:verify", {
                address: contractAddress,
                constructorArguments: [eventOwner.address],
            });
            console.log("Contract verified on Etherscan");
        } catch (error) {
            if (error instanceof Error) {
                console.log("Verification failed:", error.message);
            } else {
                console.log("Verification failed:", error);
            }
        }
    }
    
    // Test contract functionality
    console.log("\n--- Testing Contract Functionality ---");

    // creating adding an admin
    console.log("\n--- Adding Admin ---");
    const addAdminTx = await eventTicketing.connect(owner).addAdmin(eventOwner.address);
    await addAdminTx.wait(); // Wait for transaction confirmation
    console.log(`Admin added: ${eventOwner.address}`);

    // Check if the admin was added
    const isAdmin = await eventTicketing.admins(eventOwner.address);
    console.log(`Is ${eventOwner.address} an admin? ${isAdmin}`);

    // Remove an admin
    console.log("\n--- Removing Admin ---");
    const removeAdminTx = await eventTicketing.connect(owner).removeAdmin(eventOwner.address);
    await removeAdminTx.wait(); // Wait for transaction confirmation
    console.log(`Admin removed: ${eventOwner.address}`);
    // Check if the admin was removed
    const isAdminAfterRemoval = await eventTicketing.admins(eventOwner.address);
    console.log(`Is ${eventOwner.address} an admin after removal? ${isAdminAfterRemoval}`);

    // Create an event
    console.log("\n--- Creating Event ---");
    const eventTitle = "Concert";
    const eventImageUrl = "https://example.com/image.jpg";
    const eventLocation = "Stadium";
    const eventDescription = "A great concert!";
    const eventDate = Math.floor(Date.now() / 1000) + 86400; // 1 day from now

    console.log(`Creating event: ${eventTitle   } at ${eventLocation}`);
    const tx = await eventTicketing.connect(eventOwner).createEvent(
        eventTitle,
        eventImageUrl,
        eventLocation,
        eventDescription,
        eventDate
    );
    await tx.wait(); // Wait for transaction confirmation

    console.log(`Event created: ${eventTitle}`);

    // Get event details by ID (assuming events mapping uses ID)
    try {
        const eventDetails = await eventTicketing.events(0);
        console.log(`\nEvent Details:`);
        console.log(`- Title: ${eventDetails.title}`);
        console.log(`- Location: ${eventDetails.location}`);
        console.log(`- Description: ${eventDetails.description}`);
        console.log(`- Date: ${eventDetails.eventDate}}`);
    } catch (error) {
        if (error instanceof Error) {
            console.log("Error fetching event details:", error.message);
        } else {
            console.log("Error fetching event details:", error);
        }
    }

    // Create a ticket type
    console.log("\n--- Creating Ticket Type ---");
    const ticketTypeName = "VIP Ticket";
    const ticketTypePrice = hre.ethers.parseEther("0.1"); // 0.1 ETH
    const ticketTypeMaxSupply = 100;
    const dataURI = "https://example.com/event/1";


    console.log(`Creating ticket type: ${ticketTypeName}`);
    const tx2 = await eventTicketing.connect(eventOwner).createTicketType(
        0, // Assuming event ID is 0
        ticketTypeName,
        ticketTypePrice,
        ticketTypeMaxSupply,
        dataURI,
    );
    await tx2.wait(); // Wait for transaction confirmation

    console.log(`Ticket type created: ${ticketTypeName}`);

    console.log("\n --- Updating Event Ticketing Contract ---");
    // Update event details
    const updatedEventTitle = "Updated Concert";
    const updatedEventLocation = "Updated Stadium";
    const updatedEventDescription = "An even greater concert!";
    const updatedEventDate = Math.floor(Date.now() / 1000) + 172
800; // 2 days from now
    const updateTx = await eventTicketing.connect(eventOwner).updateEvent(
        0, // Assuming event ID is 0
        updatedEventTitle,
        dataURI,
        updatedEventLocation,
        updatedEventDescription,
        updatedEventDate
    );
    await updateTx.wait(); // Wait for transaction confirmation
    console.log(`Event updated: ${updatedEventTitle}`);

    console.log("\n--- Minting Ticket ---");
    // Buy a ticket
    const ticketTypeId = 0; // Assuming ticket type ID is 0
    const tx3 = await eventTicketing.connect(eventTicketBuyer).mintTicket(
        ticketTypeId,
        { value: ticketTypePrice }        
    );
    await tx3.wait(); // Wait for transaction confirmation
    console.log(`Ticket minted for ticket type ID: ${ticketTypeId}`);

    // Redeem a ticket
    console.log("\n--- Redeeming Ticket ---");
    const ticketId = 0; // Assuming ticket ID is 0
    const tx4 = await eventTicketing.connect(eventTicketBuyer).redeemTicket(ticketId);
    await tx4.wait(); // Wait for transaction confirmation
    console.log(`Ticket with ID ${ticketId} redeemed successfully`);

    
    // Save deployment info
    const deploymentInfo = {
        contractAddress,
        network: hre.network.name,
        deployer: owner.address,
        blockNumber: await hre.ethers.provider.getBlockNumber(),
        timestamp: new Date().toISOString()
    };
    
    console.log("\n--- Deployment Summary ---");
    console.log(JSON.stringify(deploymentInfo, null, 2));
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("Deployment failed:", error);
        process.exit(1);
    });