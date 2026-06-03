
### Description
Stablecoin
1. Relative Stability: Anchored (Pegged) to USD
   - Chainlink Price Feed
   - Function to exchange
2. Stability Mechanism (Minting): Algorithmic (Decentralized)
   - Mint with collateral
3. Collateral: Exogenous (Cryptocurrencies: wETC, wBTC)


### Status
Finished, tested locally, but don't deployed to testnet

### To-dos
- Deploy to testnet
- Write appropriate commands in ```./commands.bash```


### Set up
Install foundry dependences:  
```forge install foundry-rs/forge-std@v1.16.1 --no-git```   
```forge install openzeppelin/openzeppelin-contracts@v5.6.1 --no-git```  
```forge install cyfrin/foundry-devops@0.4.0 --no-git```  
```forge install smartcontractkit/chainlink-local@v0.2.9-beta.0 --no-git --no-git```
```forge install smartcontractkit/chainlink-brownie-contracts@1.3.0 --no-git```

### Deployments and interactions
Don't deploy