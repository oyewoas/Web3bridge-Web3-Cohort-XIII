// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";


const EventTicketingModule = buildModule("EventTicketingModule", (m) => {

  const eventTicketing = m.contract("EventTicketing", []);

  return { eventTicketing };
});

export default EventTicketingModule;
