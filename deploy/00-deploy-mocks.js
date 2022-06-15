const { network } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")

const BASE_FEE = ethers.utils.parseEther("0.25") //0.25 link per req, since local enviornment is payed in eth
const GAS_PRICE_LINK = 1e9 // is used to offset gas for node operators

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId

    if (chainId == 31337) {
        log("Local network detected, deploying mocks")
        // Deploys the mock vrf
        const mockraffle = await deploy("VRFCoordinatorV2Mock", {
            // Just use full file name no extension, no need to target folder its specifically in
            from: deployer,
            args: [BASE_FEE, GAS_PRICE_LINK],
            log: true,
            waitConfirmations: network.config.blockConfirmations || 1,
        })
        log("Mocks deployed")
        log("------------------------------------------------------------------------")
    }
}

module.exports.tags = ["all", "mocks"]
