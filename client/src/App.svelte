<script>
	import axios from 'axios';
	import { create } from 'ipfs-http-client';
	import Web3 from 'web3';
	import ScamFactory from '../../blockchain/artifacts/contracts/ScamFactory.sol/ScamFactory.json';
	import NewCollection from '../../blockchain/artifacts/contracts/NewCollection.sol/NewCollection.json'; 
	import pica from 'pica';
  
	const NUMS_OF_NFT = 1;
	const DEPLOYED_NETWORK = 'http://localhost:8545';
	const CONTRACT_ADDRESS = process.env.DEPLOYED_CONTRACT;
	const web3 = new Web3(DEPLOYED_NETWORK);
  	const scamFactoryContract = new web3.eth.Contract(ScamFactory.abi, CONTRACT_ADDRESS);

	let file;
	let traits = [];
	let metadataArray = [];
	// const projectId = process.env.INFURA_PROJECT_ID;
    // const projectSecret = process.env.INFURA_PROJECT_SECRET;
    // const authString = `Basic ${btoa(`${projectId}:${projectSecret}`)}`;
  
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
			console.log(res.data);
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

		for (let i = 0; i < NUMS_OF_NFT; i++) {
			const shuffledParts = shuffle(imageParts);
			traits = shuffledParts.map(part => part.id);

			const resultCanvas = document.createElement('canvas');
			resultCanvas.width = partSize * 2 * 10;
			resultCanvas.height = partSize * 2 * 10;
			const resultCtx = resultCanvas.getContext('2d');

			shuffledParts.forEach((part, index) => {
				const col = index % 2; // Column index
				const row = Math.floor(index / 2); // Row index
				const partCanvas = document.createElement('canvas');
				partCanvas.width = partSize * 10;
				partCanvas.height = partSize * 10;
				const partCtx = partCanvas.getContext('2d');
				const blobUrl = URL.createObjectURL(part.image);
				const img = new Image();

				img.onload = function() {
					partCtx.drawImage(img, 0, 0, partSize, partSize);
					resultCtx.drawImage(partCanvas, col * partSize, row * partSize, partSize, partSize);
					URL.revokeObjectURL(blobUrl);
				};
				img.src = blobUrl;
			});

			// Wait for all images to load into the canvas
			await new Promise(resolve => setTimeout(resolve, 100)); // Ensure all images are loaded

			resultCanvas.toBlob(async function(blob) {
				// This is the correct scope for using the 'blob'
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
							value: shuffledParts.join('') === '1234' ? 'legend' : 'abnormal'
						},
					],
				};

				const metadataFile = new File([JSON.stringify(metadata)], `metadata-${i}.json`, { type: 'application/json' });
				const uploadedMetadataData = await uploadToPinata(metadataFile);
				const metadataUrl = `https://gateway.pinata.cloud/ipfs/${uploadedMetadataData.IpfsHash}`;
				metadataArray.push(metadataUrl);
			}, 'image/png');
		}
		const accounts = await web3.eth.getAccounts()
		const collectionName = 'My NFT Collection';
		const collectionSymbol = 'MNFT';
		await scamFactoryContract.methods.createCollection(collectionName, collectionSymbol, metadataArray).send({ from: accounts[0] });
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


</script>

<main>
	<h1>NFT Generator</h1>
	<input type="file" on:change={handleFileChange} accept="image/*" />
	<button on:click={generateNFTs}>Generate NFTs</button>

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