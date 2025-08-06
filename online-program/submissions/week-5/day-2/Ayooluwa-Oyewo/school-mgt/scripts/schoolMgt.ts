import hre from "hardhat";

async function main() {
    const [owner, principal, student] = await hre.ethers.getSigners();
    
    console.log("Deploying SchoolMgt contract...");
    console.log("Principal address:", principal.address);
    
    // Deploy the SchoolMgt contract
    const SchoolMgt = await hre.ethers.getContractFactory("SchoolMgt");
    const schoolMgt = await SchoolMgt.deploy(principal.address);
    await schoolMgt.waitForDeployment();
    
    const contractAddress = await schoolMgt.getAddress();
    console.log(`SchoolMgt deployed to: ${contractAddress}`);
    
    // Verify deployment on network (uncomment for testnets/mainnet)
    if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
        console.log("Waiting for block confirmations...");
        await schoolMgt.deploymentTransaction()?.wait(6);
        
        try {
            await hre.run("verify:verify", {
                address: contractAddress,
                constructorArguments: [principal.address],
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
    
    // Register a student
    const studentName = "John Doe";
    const studentAge = 12;
    const studentGrade = 1;
    
    console.log(`Registering student: ${studentName}`);
    const tx = await schoolMgt.connect(principal).registerStudent(
        student.address, 
        studentName, 
        studentAge, 
        studentGrade
    );
    await tx.wait(); // Wait for transaction confirmation
    
    console.log(`Student registered: ${studentName}`);
    console.log(`Student count: ${await schoolMgt.studentCount()}`);
    
    // Get student details by ID (assuming students mapping uses ID)
    try {
        const studentDetails = await schoolMgt.students(0);
        console.log(`\nStudent Details:`);
        console.log(`- Name: ${studentDetails.name}`);
        console.log(`- Age: ${studentDetails.age}`);
        console.log(`- Grade: ${studentDetails.grade}`);
        console.log(`- Address: ${student.address}`);
    } catch (error) {
        if (error instanceof Error) {
            console.log("Error fetching student details:", error.message);
        } else {
            console.log("Error fetching student details:", error);
        }
    }
    
    // Get all students
    try {
        const allStudents = await schoolMgt.getAllStudents();
        console.log(`\nTotal Students: ${allStudents.length}`);
        
        // Log details of all students
        allStudents.forEach((student, index) => {
            console.log(`Student ${index + 1}:`, {
                name: student.name,
                age: student.age.toString(),
                grade: student.grade.toString()
            });
        });
    } catch (error) {
        if (error instanceof Error) {
            console.log("Error fetching all students:", error.message);
        } else {
            console.log("Error fetching all students:", error);
        }
    }
    
    // Save deployment info
    const deploymentInfo = {
        contractAddress,
        network: hre.network.name,
        deployer: owner.address,
        principal: principal.address,
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