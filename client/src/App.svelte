<script>
	export let name;

	let imageUrl = '';
	let traits = [];
	let legendCount = 0;
	let abnormalCount = 0;
	let metadataArray = [];
    
	async function generateNFTs() {
	  const ipfs = create({ host: 'ipfs.infura.io', port: 5001, protocol: 'https' });

	  const response = await fetch(imageUrl);
	  const buffer = await response.arrayBuffer();
	  const image = sharp(new Uint8Array(buffer)).resize(32, 32);

	  const imageParts = [];
	  for (let i = 0; i < 2; i++) {
		for (let j = 0; j < 2; j++) {
		  const part = image.clone().extract({ left: j * 16, top: i * 16, width: 16, height: 16 });
		  imageParts.push({ id: i * 2 + j + 1, image: part });
		}
	  }

	  const shuffledParts = shuffle(imageParts);
	  traits = shuffledParts.map(part => part.id);

	  const imageWidth = 320;
	  const imageHeight = 320;
	  const numImages = 10;

	  for (let i = 0; i < numImages; i++) {
		const newImage = sharp({
		  create: {
			width: imageWidth,
			height: imageHeight,
			channels: 4,
			background: { r: 0, g: 0, b: 0, alpha: 0 }
		  }
		});

		for (let j = 0; j < traits.length; j++) {
		  const part = imageParts.find(p => p.id === traits[j]);
		  const partImage = await part.image.toBuffer();
		  newImage.composite([{
			input: partImage,
			top: Math.floor(j / 2) * (imageHeight / 2),
			left: (j % 2) * (imageWidth / 2)
		  }]);
		}

		const grade = traits.join('') === '1234' ? 'legend' : 'abnormal';
		grade === 'legend' ? legendCount++ : abnormalCount++;

		const imageBuffer = await newImage.png().toBuffer();

		const imageResult = await ipfs.add(imageBuffer);
		const imageUrl = `https://ipfs.io/ipfs/${imageResult.path}`;

		const metadata = {
		  name: `NFT #${i + 1}`,
		  description: `A unique NFT with traits: ${traits.join(', ')}`,
		  image: imageUrl,
		  attributes: [
			{
			  trait_type: 'Grade',
			  value: grade,
			},
		  ],
		};
		const metadataString = JSON.stringify(metadata);

		const metadataResult = await ipfs.add(metadataString);
		const metadataUrl = `https://ipfs.io/ipfs/${metadataResult.path}`;
		metadataArray.push(metadataUrl);
	  }

	  const web3 = new Web3('http://localhost:8545');
	  const accounts = await web3.eth.getAccounts();
	  const networkId = await web3.eth.net.getId();
	  const deployedNetwork = ScamFactory.networks[networkId];
	  const contract = new web3.eth.Contract(ScamFactory.abi, deployedNetwork && deployedNetwork.address);
	  const collectionName = 'My NFT Collection';
	  const collectionSymbol = 'MNFT';
	  await contract.methods.createCollection(collectionName, collectionSymbol, metadataArray).send({ from: accounts[0] });
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
	<input type="text" bind:value={imageUrl} placeholder="Enter image URL" />
	<button on:click={generateNFTs}>Generate NFTs</button>
	<p>Legend Count: {legendCount}</p>
	<p>Abnormal Count: {abnormalCount}</p>
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