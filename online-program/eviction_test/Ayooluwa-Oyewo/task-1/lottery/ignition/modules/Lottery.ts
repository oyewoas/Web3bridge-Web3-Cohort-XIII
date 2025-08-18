import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("LotteryModule", (m) => {
  // Example values — replace with real ones
  const vrfCoordinator = "0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B";
  const gasLane = "0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae";
  const subscriptionId = "30684524537172447346142561634491626234034155162608432604937121290879"; // from VRF subscription
  const callbackGasLimit = 500000;

  const lottery = m.contract("Lottery", [
    vrfCoordinator,
    gasLane,
    subscriptionId,
    callbackGasLimit,
  ]);

  // Call start function (if your contract has one)
  m.call(lottery, "toggleLottery", []); // enable lottery

  return { lottery };
});
