# SCAM FACTORY
![image](https://github.com/NTF-marketplace/scam-factory/assets/52898964/b07f3c26-d79c-4d99-99ce-af426b4af731)


## Usage (for Develop..)
### 1. blockchain
```bash
# terminal 1
> git clone <this project>
> cd blockchain
> npx hardhat node

# new terminal tab
> cd blockchain
> npx hardhat run scripts/deploy.js --network localhost
ScamFactory deployed to: 0x5FbDB2315678afecb367f032d93F642f64180aa3      <--- Remember this hash .. --- (1)
Created collections: Result(0) []
```

### 2. .env setting
1. copy .env_example to .env
2. join the https://www.pinata.cloud/
3. get API KEY
4. PINATA_SECRET_KEY=`here your API KEY`
5. DEPLOYED_CONTRACT=`here remember hash (1)`

### 3. run client
```bash
> cd client
> npm run dev
```
