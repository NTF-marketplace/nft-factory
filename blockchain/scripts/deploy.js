// scripts/deploy.js
async function main() {
    // 컨트랙트 팩토리 가져오기
    const ScamFactory = await ethers.getContractFactory("ScamFactory");

    // 컨트랙트 배포
    const scamFactory = await ScamFactory.deploy();
    console.log("ScamFactory deployed to:", scamFactory.target);

    // 생성된 컬렉션의 주소들 가져오기
    const collections = await scamFactory.getCollections();
    console.log("Created collections:", collections);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
