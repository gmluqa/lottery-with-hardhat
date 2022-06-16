// Script that automates the entry of a user into the raffle

const { ethers } = require("hardhat")

async function enterRaffle() {
    // https://docs.ethers.io/ethers-app/html/dev-api-contracts.html#connecting-to-a-contract
    // gets address from deployments/rinkeby/Raffle.json[address]
    const raffle = await ethers.getContract("Raffle")
    const entranceFee = await raffle.getEntranceFee()
    await raffle.enterRaffle({ value: entranceFee })
    console.log("Entered!")
}

enterRaffle()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
