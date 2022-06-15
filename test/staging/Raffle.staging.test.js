const { getNamedAccounts, deployments, ethers, network } = require("hardhat")
const { developmentChains, networkConfig } = require("../../helper-hardhat-config")
const { assert, expect } = require("chai")

developmentChains.includes(network.name)
    ? describe.skip
    : describe("Raffle Unit Tests", function () {
          let raffle, raffleEntranceFee, deployer

          beforeEach(async function () {
              deployer = (await getNamedAccounts()).deployer // .deployer to extrapolate from hhconfig.js, [0]'th account is default
              raffle = await ethers.getContract("Raffle", deployer) // Gets contract from delpoyer, assuming Raffle has been deployed
              raffleEntranceFee = await raffle.getEntranceFee()
          })
          describe("fulfillRandomWords", function () {
              it("works with live Chainlink Keepers and CL VRF, we get a random winner", async function () {
                  const startingTimeStamp = await raffle.getLatestTimeStamp()
                  const accounts = await ethers.getSigners()

                  console.log("Setting up listener")

                  await new Promise(async (resolve, reject) => {
                      raffle.once("WinnerPicked", async () => {
                          console.log("WinnerPicked event emitted!!!")

                          try {
                              const recentWinner = await raffle.getWinner()
                              const raffleState = await raffle.getRaffleState()
                              const winnerEndingBalance = await accounts[0].getBalance()
                              const endingTimeStamp = await raffle.getLatestTimeStamp()
                              await expect(raffle.getIndexedPlayer(0)).to.be.reverted // will be reverted since array should be cleared
                              assert.equal(recentWinner.toString(), accounts[0].address)
                              assert.equal(raffleState, 0) // enum assumed to be OPEN (0)
                              assert.equal(
                                  winnerEndingBalance.toString(),
                                  winnerStartingBalance.add(raffleEntranceFee).toString()
                              )
                              assert(endingTimeStamp > startingTimeStamp)
                              resolve()
                          } catch (error) {
                              console.log(error)
                              reject(error)
                          }
                      })
                      // We set up a listener first, listener set, then we enter the raffle and wait for resolve/reject
                      console.log("Entering Raffle. . .")
                      await raffle.enterRaffle({ value: raffleEntranceFee })
                      const winnerStartingBalance = await accounts[0].getBalance()
                  })
              })
          })
      })
