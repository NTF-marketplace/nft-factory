<script>
	import axios from 'axios';
	import Web3 from 'web3';
	import ScamFactory from '../../blockchain/artifacts/contracts/ScamFactory.sol/ScamFactory.json';
	import NewCollection from '../../blockchain/artifacts/contracts/NewCollection.sol/NewCollection.json'; 
	import pica from 'pica';
  
	const NUMS_OF_NFT = 1;
	const DEPLOYED_NETWORK = process.env.DEPLOYED_NETWORK;
	const CONTRACT_ADDRESS = process.env.DEPLOYED_CONTRACT;
	const web3 = new Web3(window.ethereum); 
	// const web3 = new Web3(DEPLOYED_NETWORK);
  	const scamFactoryContract = new web3.eth.Contract(ScamFactory.abi, CONTRACT_ADDRESS);

	let file;
  
	const picaResizer = pica();

	const PINATA_GW = process.env.PINATA_GATEWAY;
	const PINATA_JWT = process.env.PINATA_SECRET_KEY;

	async function disconnectMetamask() {
		currentAccount = null;
		paymentToken = 'ETH';
		balance = '0';
	}

	let currentAccount = null;
	let paymentToken = 'ETH';
	let balance = '0';
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
				if (networkId === 1) {
					paymentToken = 'ETH'; // 메인넷
				// } else if (networkId === 137) {
				// 	paymentToken = 'MATIC';
				// } else if (networkId === 56) {
				// 	paymentToken = 'BNB';
				// } else if (networkId === ) {
				// 	paymentToken = 'gETH'; // Goerli 테스트넷
				// } else if (networkId === 42) {
				// 	paymentToken = 'kETH'; // Kovan 테스트넷
				} else {
					paymentToken = 'ETH'; // 알 수 없는 네트워크
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
			console.log("uploadToPinanta:", res.data);
			return res.data;
		} catch (error) {
			console.log(error);
		}
	}


	async function updateBalance() {
		balance = await web3.eth.getBalance(currentAccount);
		balance = web3.utils.fromWei(balance, 'ether'); 
	}

	async function generateNFTs() {
		if (!currentAccount) {
			alert("Please connect to Metamask first");
			return;
		}
		if (!file) {
			alert('Please select an image file.');
			return;
		}
		const collectionNameInput = document.getElementById('collectionName').value;
		const collectionSymbolInput = document.getElementById('collectionSymbol').value;
		const numNFTsInput = document.getElementById('numOfNFTs').value;

		const collectionName = collectionNameInput || `Collection-${Math.random().toString(36).substr(2, 9)}`;
		const collectionSymbol = collectionSymbolInput || `SYM-${Math.random().toString(36).substr(2, 5)}`;
		const numsOfNFT = numNFTsInput || NUMS_OF_NFT;

		let traits = [];
		let metadataArray = [];
	
		const reader = new FileReader();
	
		reader.onload = async (event) => {
			const partSize = 16; // each part is 16x16 pixels

			const srcImage = new Image();
			srcImage.src = event.target.result;

			await new Promise(resolve => srcImage.onload = resolve);

			const canvas = document.createElement('canvas');
			const ctx = canvas.getContext('2d');
			canvas.width = partSize * 2;
			canvas.height = partSize * 2;

			// Resize the image using pica
			await picaResizer.resize(srcImage, canvas);

			const imageParts = [];
			console.log("=======1==========");
			// Extract parts from the resized image
			for (let i = 0; i < 2; i++) {
				for (let j = 0; j < 2; j++) {
					const partCanvas = document.createElement('canvas');
					partCanvas.width = partSize;
					partCanvas.height = partSize;
					const partCtx = partCanvas.getContext('2d');

					partCtx.drawImage(canvas, j * partSize, i * partSize, partSize, partSize, 0, 0, partSize, partSize);
					const partImage = await picaResizer.toBlob(partCanvas, 'image/png');
					imageParts.push({ id: i * 2 + j + 1, image: partImage });
				}
			}

			console.log("========2=========");

			for (let i = 0; i < numsOfNFT; i++) {
				const shuffledParts = shuffle(imageParts);
				traits = shuffledParts.map(part => part.id);

				const resultCanvas = document.createElement('canvas');
				resultCanvas.width = partSize * 2 * 10;
				resultCanvas.height = partSize * 2 * 10;
				const resultCtx = resultCanvas.getContext('2d');

				
				await Promise.all(shuffledParts.map(part => {
					return new Promise((resolve, reject) => {
						const col = shuffledParts.indexOf(part) % 2; // Column index
						const row = Math.floor(shuffledParts.indexOf(part) / 2); // Row index
						const partCanvas = document.createElement('canvas');
						partCanvas.width = partSize * 10;
						partCanvas.height = partSize * 10;
						const partCtx = partCanvas.getContext('2d');
						
						// Disable image smoothing
						partCtx.imageSmoothingEnabled = false;

						const blobUrl = URL.createObjectURL(part.image);
						const img = new Image();

						img.onload = () => {
							// Draw the image on the part canvas, resizing it without smoothing.
							partCtx.drawImage(img, 0, 0, partCanvas.width, partCanvas.height);

							// Ensure the result canvas also has image smoothing disabled
							resultCtx.imageSmoothingEnabled = false;
							resultCtx.drawImage(partCanvas, col * partCanvas.width, row * partCanvas.height, partCanvas.width, partCanvas.height);

							URL.revokeObjectURL(blobUrl);
							resolve();
						};
						img.onerror = () => {
							console.error("Image load failed");
							reject(new Error("Image load failed for " + blobUrl));
						};
						img.src = blobUrl;
					});
				}));

				console.log("=======3==========");

				await new Promise(resolve => resultCanvas.toBlob(async (blob) => {
					const imageFile = new File([blob], `nft-${i}.png`, { type: 'image/png' });
					const uploadedImageData = await uploadToPinata(imageFile);
					const uploadedImageUrl = `https://ipfs.io/ipfs/${uploadedImageData.IpfsHash}`;

					const metadata = {
						name: `NFT #${i + 1}`,
						description: `A unique NFT with traits: ${traits.join(', ')}`,
						image: uploadedImageUrl,
						attributes: [
							{
								trait_type: 'Grade',
								value: shuffledParts.map(part => part.id).join('') === '1234' ? 'legend' : 'abnormal',
							},
							{
								trait_type: 'Part 1',
								value: shuffledParts[0].id,
							},
							{
								trait_type: 'Part 2',
								value: shuffledParts[1].id,
							},
							{
								trait_type: 'Part 3',
								value: shuffledParts[2].id,
							},
							{
								trait_type: 'Part 4',
								value: shuffledParts[3].id,
							},
						],
					};

					const metadataFile = new File([JSON.stringify(metadata)], `metadata-${i}.json`, { type: 'application/json' });
					const uploadedMetadataData = await uploadToPinata(metadataFile);
					const metadataUrl = `https://ipfs.io/ipfs/${uploadedMetadataData.IpfsHash}`;
					metadataArray.push(metadataUrl);
					resolve();
				}, 'image/png'));

			}
			console.log("=======4==========");

			console.log("nft owner:", currentAccount);

			const result = await scamFactoryContract.methods.createCollection(collectionName, collectionSymbol, metadataArray)
			.send({ 
				from: currentAccount, 
			}).catch((error) => {
				console.error("트랜잭션 실행 중 오류 발생:", error);
			});

			console.log("createCollection:", result);
		};

	  	reader.readAsDataURL(file);
		await updateBalance();
	}
  
	function handleFileChange(event) {
	  file = event.target.files[0];
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
			const response = await axios.get(metadataURIs[i]);
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
		<input type="file" on:change={handleFileChange} accept="image/*" />
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