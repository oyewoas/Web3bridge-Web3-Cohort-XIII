import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("SchoolMgt", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployOneYearLockFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, principal, student, otherAccount] =
      await hre.ethers.getSigners();

    const SchoolMgt = await hre.ethers.getContractFactory("SchoolMgt");
    const schoolMgt = await SchoolMgt.deploy(principal.address);

    return { schoolMgt, owner, principal, student, otherAccount };
  }

  describe("Deployment", function () {
    it("Should deploy successfully", async function () {
      const { schoolMgt, principal } = await loadFixture(
        deployOneYearLockFixture
      );

      expect(await schoolMgt.principal()).to.equal(principal.address);
    });
  });

  describe("Registering Students", function () {
    it("Should register a student successfully", async function () {
      const { schoolMgt, principal, student } = await loadFixture(
        deployOneYearLockFixture
      );
      const studentName = "John Doe";

      await expect(
        schoolMgt
          .connect(principal)
          .registerStudent(student.address, studentName, 12, 1)
      )
        .to.emit(schoolMgt, "StudentRegistered")
        .withArgs(1, studentName);

      const studentDetails = await schoolMgt.students(0);
      expect(studentDetails.name).to.equal(studentName);
      expect(studentDetails.age).to.equal(12);
      expect(studentDetails.grade).to.equal(1);
      expect(studentDetails.gender).to.equal(1);
      expect(await schoolMgt.studentCount()).to.equal(1);
    });

    it("Should not allow non-principal to register a student", async function () {
      const { schoolMgt, otherAccount, student } = await loadFixture(
        deployOneYearLockFixture
      );
      const studentName = "Jane Doe";

      await expect(
        schoolMgt
          .connect(otherAccount)
          .registerStudent(student.address, studentName, 12, 1)
      ).to.be.revertedWithCustomError(schoolMgt, "Unauthorized");
    });
  });
  describe("Getting Student Details", function () {
    it("Should return student details by ID", async function () {
      const { schoolMgt, principal, student } = await loadFixture(
        deployOneYearLockFixture
      );
      const studentName = "John Doe";

      await schoolMgt
        .connect(principal)
        .registerStudent(student.address, studentName, 12, 1);
      const studentDetails = await schoolMgt.getAllStudents();

      expect(studentDetails[0].name).to.equal(studentName);
      expect(studentDetails[0].age).to.equal(12);
      expect(studentDetails[0].grade).to.equal(1);
    });
  });
});
