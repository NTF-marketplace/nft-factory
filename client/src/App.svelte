<script>
	import axios from 'axios';
	import Web3 from 'web3';
	import ScamFactory from '../../blockchain/artifacts/contracts/ScamFactory.sol/ScamFactory.json';
	import NewCollection from '../../blockchain/artifacts/contracts/NewCollection.sol/NewCollection.json'; 
	import pica from 'pica';

	// const DEPLOYED_NETWORK = process.env.DEPLOYED_NETWORK;
	const CONTRACT_ADDRESS = process.env.DEPLOYED_CONTRACT;
	const web3 = new Web3(window.ethereum); 
	const scamFactoryContract = new web3.eth.Contract(ScamFactory.abi, CONTRACT_ADDRESS);

	// const PINATA_GW = process.env.PINATA_GATEWAY;
	const PINATA_JWT = process.env.PINATA_SECRET_KEY;

	let currentAccount = null;
	let paymentToken = 'ETH';
	let balance = '0';
	$: paymentToken; // Make paymentToken reactive

	async function disconnectMetamask() {
		currentAccount = null;
		paymentToken = 'ETH';
		balance = '0';
	}

	async function connectMetamask() {
		let provider;

		if (window.ethereum.providers) {
			window.ethereum.providers.forEach(p => {
				if (p.isMetaMask) provider = p;
			});
		} else if (window.ethereum.isMetaMask) {
			provider = window.ethereum;
		} else {
			alert("Metamask not detected");
		}

		if (provider) {
			try {
				const accounts = await provider.request({ method: 'eth_requestAccounts' });
				currentAccount = accounts[0];
				console.log("Connected account:", currentAccount);

				const networkId = await web3.eth.net.getId();
				console.log("Network ID:", networkId);
				switch (Number(networkId)) {
					case 1:
						paymentToken = 'ETH'; // Mainnet
						console.log("eth");
						break;
					case 137:
					case 80001:
					case 80002:
						paymentToken = 'MATIC'; // Polygon Mainnet and Testnet
						console.log("matic");
						break;
					default:
						console.log("etc");
						paymentToken = 'ETH'; // Unknown network
				}
				await updateBalance();
			} catch (error) {
				console.error("Error connecting to Metamask:", error);
			}
		} else {
			alert("Metamask not detected");
		}
	}

	async function uploadToPinata(file) {
		try {
			const formData = new FormData();
			formData.append("file", file);

			const res = await axios.post(
				"https://api.pinata.cloud/pinning/pinFileToIPFS",
				formData,
				{
					headers: {
						Authorization: `Bearer ${PINATA_JWT}`,
					},
				}
			);
			console.log("uploadToPinata:", res.data);
			return res.data;
		} catch (error) {
			console.log(error);
		}
	}

	async function updateBalance() {
		balance = await web3.eth.getBalance(currentAccount);
		balance = web3.utils.fromWei(balance, 'ether'); 
	}

	let files = [];
	function handleFileChange(event) {
		files = [...event.target.files];
	}
  
	function shuffle(array) {
	  let currentIndex = array.length, temporaryValue, randomIndex;
	  while (0 !== currentIndex) {
		randomIndex = Math.floor(Math.random() * currentIndex);
		currentIndex -= 1;
		temporaryValue = array[currentIndex];
		array[currentIndex] = array[randomIndex];
		array[randomIndex] = temporaryValue;
	  }
	  return array;
	}

	async function processFiles(files) {
		let metadataArray = [];
		const filePromises = files.map(async (file, fileIndex) => {
			const traits = shuffle([1, 2, 3, 4]);
			const reader = new FileReader();

			const fileLoadPromise = new Promise((resolve, reject) => {
				reader.onload = async (event) => {
					try {
						const imageFile = new File([event.target.result], `nft-${fileIndex}.png`, { type: 'image/png' });
						const uploadedImageData = await uploadToPinata(imageFile);
						const uploadedImageUrl = `https://ipfs.io/ipfs/${uploadedImageData.IpfsHash}`;

						const randomName = `${Math.random().toString(36).substr(2, 9)}`;

						const metadata = {
							name: `NFT #${randomName + 1}`,
							description: `A unique NFT from image ${randomName + 1}`,
							image: uploadedImageUrl,
							attributes: [
								{
									trait_type: 'Grade',
									value: traits.join('') === '1234' ? 'legend' : 'abnormal',
								},
								{
									trait_type: 'Part 1',
									value: traits[0]
								},
								{
									trait_type: 'Part 2',
									value: traits[1]
								},
								{
									trait_type: 'Part 3',
									value: traits[2]
								},
								{
									trait_type: 'Part 4',
									value: traits[3]
								},
								{
									trait_type: 'random Name',
									value: randomName
								},
							],
						};

						const metadataFile = new File([JSON.stringify(metadata)], `metadata-${fileIndex}.json`, { type: 'application/json' });
						const uploadedMetadataData = await uploadToPinata(metadataFile);
						const metadataUrl = `https://ipfs.io/ipfs/${uploadedMetadataData.IpfsHash}`;
						metadataArray.push(metadataUrl);
						resolve();
					} catch (error) {
						reject(error);
					}
				};
			});

			reader.readAsArrayBuffer(file);
			return fileLoadPromise;
		});

		await Promise.all(filePromises);
		return metadataArray;
	}

	async function sendTransaction(method, fromAddress) {
		const gasEstimate = await method.estimateGas({ from: fromAddress });
		const gasPrice = await web3.eth.getGasPrice();
		const result = await method.send({
			from: fromAddress,
			gas: gasEstimate,
			gasPrice: gasPrice,
		});
		return result;
	}

	async function executeTransactionWithRetries(method, fromAddress, retries = 1) {
		for (let i = 0; i < retries; i++) {
			try {
				return await sendTransaction(method, fromAddress);
			} catch (error) {
				console.error(`Attempt ${i + 1} failed: ${error.message}`);
				if (i === retries - 1) throw error;
			}
		}
	}

	async function generateNFTs() {
		if (!currentAccount) {
			alert("Please connect to Metamask first");
			return;
		}
		if (!files || files.length === 0) {
			alert('Please select image files.');
			return;
		}
		const collectionNameInput = document.getElementById('collectionName').value;
		const collectionSymbolInput = document.getElementById('collectionSymbol').value;

		const collectionName = collectionNameInput || `Collection-${Math.random().toString(36).substr(2, 9)}`;
		const collectionSymbol = collectionSymbolInput || `SYM-${Math.random().toString(36).substr(2, 5)}`;

		const metadataArray = await processFiles(files);
		console.log("metadataArray: ", metadataArray);

		const createCollectionMethod = scamFactoryContract.methods.createCollection(collectionName, collectionSymbol, metadataArray);
		const result = await executeTransactionWithRetries(createCollectionMethod, currentAccount);
		console.log("createCollection:", result);
		await updateBalance();
	}

	async function addNFTsToExistingCollection(collectionAddress) {
		if (!currentAccount) {
			alert("Please connect to Metamask first");
			return;
		}
		if (!files || files.length === 0) {
			alert('Please select image files.');
			return;
		}

		const metadataArray = await processFiles(files);
		console.log("metadataArray: ", metadataArray);

		const addNFTsMethod = scamFactoryContract.methods.addNFTsToCollection(collectionAddress, metadataArray);
		const result = await executeTransactionWithRetries(addNFTsMethod, currentAccount);
		console.log("addNFTsToCollection:", result);
		await updateBalance();
	}

	let collections = [];
	let nftsInCollections = [];

	async function loadCollections() {
		if (!currentAccount) {
			alert("Please connect to Metamask first");
			return;
		}
		const accounts = await web3.eth.getAccounts();

		console.log("ScamFactory Contract Address:", scamFactoryContract.options.address);
		console.log("Accounts:", accounts);
		const collectionsAddresses = await scamFactoryContract.methods.getCollections().call();
		console.log(collectionsAddresses);

		collections = collectionsAddresses;
		const collectionPromises = collectionsAddresses.map(async (address) => {
			const collectionContract = new web3.eth.Contract(NewCollection.abi, address);
			const nfts = await loadNFTs(collectionContract);
			return { address, nfts };
		});

		nftsInCollections = await Promise.all(collectionPromises);
		await updateBalance();
	}

	async function loadNFTs(collectionContract) {
		if (!currentAccount) {
			alert("Please connect to Metamask first");
			return;
		}
		console.log("NewCollection Contract Address:", collectionContract.options.address);
		const nfts = [];

		const totalSupply = await collectionContract.methods.totalSupply().call();
		console.log("totalSupply:", totalSupply);

		const tokens = await collectionContract.methods.getTokensByOwner(currentAccount).call();
		console.log("getTokensByOwner:", tokens);
		
		const metadataURIs = await collectionContract.methods.getTokensMetadataByOwner(currentAccount).call();
		console.log("metadataURIs:", metadataURIs);

		for (let i = 0; i < metadataURIs.length; i++) {
			const response = await axios.get(metadataURIs[i].metadata);
			console.log("respose: ", response);
			const metadata = response.data;
			nfts.push({
				tokenId: i,
				name: metadata.name,
				description: metadata.description,
				image: metadata.image,
				attributes: metadata.attributes
			});
		}
		return nfts;
	}
</script>

<main>
	<h1>NFT Generator</h1>
	<div>
		<input type="file" on:change={handleFileChange} accept="image/*" multiple />
		<button on:click={generateNFTs}>Generate NFTs</button>
		<button on:click={loadCollections}>Load Collections</button>
	</div>
	<div>
		<input type="text" id="collectionName" placeholder="Collection Name (Optional)" />
		<input type="text" id="collectionSymbol" placeholder="Collection Symbol (Optional)" />
		<input type="number" id="numOfNFTs" placeholder="Number of NFTs (Default: 1)" min="1" />
	</div>
	
    {#each nftsInCollections as collection}
        <div class="collection">
            <div class="collection-header">
                <span>Collection at: {collection.address}</span>
				<button on:click={() => addNFTsToExistingCollection(collection.address)}>Add NFTs to this Collection</button>
            </div>
            <div class="nft-container">
                {#each collection.nfts as nft}
                    <div class="nft">
                        <h3>{nft.name}</h3>
                        <img src={nft.image} alt={nft.name} />
                        <p>{nft.description}</p>
                        <ul>
							{#each nft.attributes as attribute}
								<li>{attribute.trait_type}: {attribute.value}</li>
							{/each}
                        </ul>
                    </div>
                {/each}
            </div>
        </div>
    {/each}
</main>
<div class="metamask-connect">
	{#if currentAccount}
		<p>Connected with {currentAccount}</p>
		<p>{paymentToken} Balance: {balance}</p>
		<button on:click={disconnectMetamask}>Disconnect</button>
	{:else}
		<button on:click={connectMetamask}>Connect Metamask</button>
	{/if}
</div>

<style>
	main {
		text-align: center;
		padding: 1em;
		max-width: 240px;
		margin: 0 auto;
	}

	h1 {
		color: #ff3e00;
		text-transform: uppercase;
		font-size: 4em;
		font-weight: 100;
	}

	@media (min-width: 640px) {
		main {
			max-width: none;
		}
	}
	.collection {
		border-bottom: 1px solid #ccc; /* 구분선 추가 */
		margin-bottom: 20px;
	}

	.collection-header {
		font-weight: bold;
		margin-bottom: 10px;
	}

	.nft-container {
		display: flex;
		flex-wrap: wrap;
		justify-content: center; /* 중앙 정렬 */
	}

	.nft {
		text-align: center; /* 텍스트 중앙 정렬 */
		margin: 10px;
		width: 200px; /* NFT 블록의 너비 설정 */
	}

	.nft ul {
		text-align: left; /* 텍스트 중앙 정렬 */
	}
	.nft img {
		max-width: 100%; /* 이미지 최대 너비 제한 */
		height: auto; /* 이미지 높이 자동 조정 */
	}

	.metamask-connect {
		position: absolute;
		top: 10px;
		right: 10px;
	}
</style>
