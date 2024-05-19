# SCAM FACTORY
POLYGON 체인의 ERC-721 NFT 생성기입니다.   
요청에 의해 업로드한 이미지에 대해서만 NFT를 생성하도록 변경했습니다.    
![image](https://github.com/NTF-marketplace/scam-factory/assets/52898964/e76fb592-6488-4b73-90dd-b72ffc4fa868)

NFT 생성자가 가스비를 내고, NFT를 소유할 수 있습니다.    
OpenSea 에서도 확인할 수 있습니다.   
<img width="1066" alt="image" src="https://github.com/NTF-marketplace/scam-factory/assets/52898964/2343734c-80ce-4fc0-acf1-17b8d7bea039">


## Usage (polygon mainnet)
자세한 내용은 https://dongkim.lol/posts/project/scam_factory/1_create_nft/#%ED%85%8C%EC%8A%A4%ED%8A%B8%EB%84%B7-%EB%B0%B0%ED%8F%AC 이 링크를 따라가세요

### 1. setting
1. git clone repository
2. open this project on VSCODE
3. join PINATA
   * https://www.pinata.cloud/
4. get API KEY
5. copy .env_example to .env
6. modify the .env file
   ```
    PINATA_GATEWAY=your_pinata_gw_here          -> unused
    PINATA_SECRET_KEY=!!!your_pinata_secret_here!!! 
    DEPLOYED_CONTRACT=0x7eA0E04cCa2d9aFa088DEa118f3C5C472d988F64
    DEPLOYED_NETWORK=http://localhost:8545      -> unused
   ```
### 2. run client
```bash
> cd client
> npm install
> npm run dev
```

### 3. connect metamask
1. check account, network

### 4. use this client!!
1. create image using midjurney
2. copy and split image
   * https://ezgif.com/sprite-cutter


<br>


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
