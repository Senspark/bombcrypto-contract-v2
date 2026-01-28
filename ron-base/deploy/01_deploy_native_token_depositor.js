const func = async function (hre) {
    const {deployments, getNamedAccounts} = hre;
    const {deploy} = deployments;

    const {deployer} = await getNamedAccounts();

    try {
        const result = await deploy("NativeTokenDepositor", {
            from: deployer,
            gasLimit: 5_000_000,
            gasPrice: 250000000, // 0.25 gwei
            args: [],
            log: true,
            proxy: {
                proxyContract: "UUPS",
                upgradeFunction: {
                    methodName: "upgradeToAndCall",
                    upgradeArgs: ['{implementation}', '{data}']
                },
                execute: {
                    init: {
                        methodName: "initialize",
                        args: [],
                        gasLimit: 1_000_000 // Gas limit for initialization
                    }
                }
            },
            autoMine: true // Force mining on local networks
        });
    } catch (e) {
        // print e, stack trace, and error message, inner error message
        console.log(e.errorDescriptor);
        console.log(e.messageArguments);
        throw e;
    }
};

module.exports = func;
func.tags = ["NativeTokenDepositor"];
func.id = "deploy_native_token_depositor"; // Unique ID for this deployment