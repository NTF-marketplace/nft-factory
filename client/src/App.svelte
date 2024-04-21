<script>
	import axios from 'axios';
	import Web3 from 'web3';
	import ScamFactory from '../../blockchain/artifacts/contracts/ScamFactory.sol/ScamFactory.json';
	import NewCollection from '../../blockchain/artifacts/contracts/NewCollection.sol/NewCollection.json'; 
	import pica from 'pica';
  
	const NUMS_OF_NFT = 1;
	const DEPLOYED_NETWORK = 'http://localhost:8545';
	const CONTRACT_ADDRESS = process.env.DEPLOYED_CONTRACT;
	// const web3 = new Web3(window.ethereum); 
	const web3 = new Web3(DEPLOYED_NETWORK);
  	const scamFactoryContract = new web3.eth.Contract(ScamFactory.abi, CONTRACT_ADDRESS);

	let file;
	let traits = [];
	let metadataArray = [];
  
	const picaResizer = pica();

	const PINATA_GW = process.env.PINATA_GATEWAY;
	const PINATA_JWT = process.env.PINATA_SECRET_KEY;

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



	async function generateNFTs() {
		if (!file) {
			alert('Please select an image file.');
			return;
		}
	
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

			for (let i = 0; i < NUMS_OF_NFT; i++) {
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
					const uploadedImageUrl = `https://gateway.pinata.cloud/ipfs/${uploadedImageData.IpfsHash}`;

					const metadata = {
						name: `NFT #${i + 1}`,
						description: `A unique NFT with traits: ${traits.join(', ')}`,
						image: uploadedImageUrl,
						attributes: [
							{
								trait_type: 'Grade',
								value: shuffledParts.map(part => part.id).join('') === '1234' ? 'legend' : 'abnormal'
							},
						],
					};

					const metadataFile = new File([JSON.stringify(metadata)], `metadata-${i}.json`, { type: 'application/json' });
					const uploadedMetadataData = await uploadToPinata(metadataFile);
					const metadataUrl = `https://gateway.pinata.cloud/ipfs/${uploadedMetadataData.IpfsHash}`;
					metadataArray.push(metadataUrl);
					resolve();
				}, 'image/png'));

			}
			console.log("=======4==========");

			const accounts = await web3.eth.getAccounts();
			const collectionName = 'My NFT Collection';
			const collectionSymbol = 'MNFT';
			console.log("nft owner:", accounts[0]);

			const result = await scamFactoryContract.methods.createCollection(collectionName, collectionSymbol, metadataArray)
			.send({ 
				from: accounts[0], 
			}).catch((error) => {
				console.error("트랜잭션 실행 중 오류 발생:", error);
			});

			console.log("createCollection:", result);
		};

	  	reader.readAsDataURL(file);
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
	}

	async function loadNFTs(collectionContract) {
		console.log("NewCollection Contract Address:", collectionContract.options.address);
		const nfts = [];
		const accounts = await web3.eth.getAccounts();

		const totalSupply = await collectionContract.methods.totalSupply().call();
		console.log("totalSupply:", totalSupply);

		const tokens = await collectionContract.methods.getTokensByOwner(accounts[0]).call();
		console.log("getTokensByOwner:", tokens);
		
		const metadataURIs = await collectionContract.methods.getTokensMetadataByOwner(accounts[0]).call();
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
	<input type="file" on:change={handleFileChange} accept="image/*" />
	<button on:click={generateNFTs}>Generate NFTs</button>
	<button on:click={loadCollections}>Load Collections</button>

	{#each nftsInCollections as collection}
	  <h2>Collection at: {collection.address}</h2>
	  <ul>
		{#each collection.nfts as nft}
		  <li>
			<h3>{nft.name}</h3>
			<img src={nft.image} alt={nft.name} />
			<p>{nft.description}</p>
			<ul>
			  {#each nft.attributes as attribute}
				<li>{attribute.trait_type}: {attribute.value}</li>
			  {/each}
			</ul>
		  </li>
		{/each}
	  </ul>
	{/each}
</main>


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
</style>