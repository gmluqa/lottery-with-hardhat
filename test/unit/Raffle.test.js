const { getNamedAccounts, deployments, ethers, network } = require("hardhat")
const { developmentChains, networkConfig } = require("../../helper-hardhat-config")
const { assert, expect } = require("chai")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Raffle Unit Tests", function () {
          let raffle, vrfCoordinatorV2Mock, raffleEntranceFee, deployer, interval
          const chainId = network.config.chainId
          beforeEach(async function () {
              deployer = (await getNamedAccounts()).deployer // .deployer to extrapolate from hhconfig.js, [0]'th account is default
              await deployments.fixture(["all"])
              raffle = await ethers.getContract("Raffle", deployer)
              vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock", deployer)
              raffleEntranceFee = await raffle.getEntranceFee()
              interval = await raffle.getInterval()
          })

          describe("constructor", function () {
              it("intitiallizes the raffle correctly", async () => {
                  // Ideally, we'd separate these out so that only 1 assert per "it" block
                  // And ideally, we'd make this check everything
                  const raffleState = (await raffle.getRaffleState()).toString()
                  assert.equal(raffleState, "0")
              })
          })
          describe("etnerRaffle", function () {
              it("Reverts when not enough ETH is paid", async function () {
                  await expect(raffle.enterRaffle()).to.be.revertedWith("Raffle__NotEnoughEth")
              })
              it("Records players when they enter", async function () {
                  await raffle.enterRaffle({ value: raffleEntranceFee })
                  const playerFromContract = await raffle.getIndexedPlayer(0)
                  assert.equal(playerFromContract, deployer)
              })

              // https://ethereum-waffle.readthedocs.io/en/latest/matchers.html?highlight=event#emitting-events
              it("Emits event on enter", async function () {
                  await expect(raffle.enterRaffle({ value: raffleEntranceFee })).to.emit(
                      raffle,
                      "RaffleEnter"
                  )
              })
              // https://hardhat.org/hardhat-network/reference#special-testing/debugging-methods
              // bookmark, want to figure out what these docs actually mean
              it("Doesn't allow entrance when raffle is calculating", async function () {
                  await raffle.enterRaffle({ value: raffleEntranceFee })
                  // https://trufflesuite.com/blog/introducing-ganache-7/#6-fast-forward-time
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  // now we "mine" a block
                  await network.provider.send("evm_mine", [])
                  // now we pretend to be a chainlink keeper
                  await raffle.performUpkeep([])
                  await expect(raffle.enterRaffle({ value: raffleEntranceFee })).to.be.revertedWith(
                      "Raffle__NotOpen"
                  )
              })
          })
          describe("CheckUpkeep", function () {
              it("Returns false if people haven't sent any ETH", async function () {
                  // https://trufflesuite.com/guides/chain-forking-exploiting-the-dao/#step-3-wait-for-the-presale-to-end
                  // Am basically fast forwarding blocktime to confirm keepers are ready to prod
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.send("evm_mine", [])
                  // bookmark, don't quite understand the need for "{}" in the const
                  const { upkeepNeeded } = raffle.callStatic.checkUpkeep() // callStatic calls the function without doing tx, would work fine without it
                  assert(!upkeepNeeded) // we assert that upkeep is not needed
              })
              it("Returns false if raffle isn't open", async function () {
                  await raffle.enterRaffle({ value: raffleEntranceFee })
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.send("evm_mine", [])
                  await raffle.performUpkeep([])
                  const raffleState = await raffle.getRaffleState()
                  const { upkeepNeeded } = await raffle.callStatic.checkUpkeep([])
                  assert.equal(raffleState.toString(), "1")
                  assert.equal(upkeepNeeded, false)
              })
          })
          describe("performUpkeep", function () {
              it("Can only run if checkupkeep is true", async function () {
                  await raffle.enterRaffle({ value: raffleEntranceFee })
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.send("evm_mine", [])
                  const tx = await raffle.performUpkeep([])
                  assert(tx) // Asserts it to be populated, else it will be false
              })
              it("Reverts when checkUpkeep is false", async function () {
                  await expect(raffle.performUpkeep([])).to.be.revertedWith(
                      "Raffle__UpkeepNotNeeded"
                  )
              })
              it("Updates the raffle state, emits and calls vrfCoordinator", async function () {
                  await raffle.enterRaffle({ value: raffleEntranceFee })
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.send("evm_mine", [])
                  const txResponse = await raffle.performUpkeep([])
                  const txReceipt = await txResponse.wait(1)
                  const requestId = txReceipt.events[1].args.requestId // Not 0th event, need 1st because there are 2 events, 1 gets emitted before this one
                  const raffleState = await raffle.getRaffleState()
                  assert(requestId.toNumber() > 0)
                  assert(raffleState.toString() == "1")
              })
          })
      })
