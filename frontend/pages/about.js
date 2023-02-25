import Head from 'next/head'

export default function About() {
  return (
    <div>
      <Head>
        <title>About SidesNFT</title>
        <meta name="description" content="About SidesNFT" />
        <link rel="icon" href="/thumbnail.png" />
      </Head>
      <div className="container">
        <div className="center-text">
          <p>SidesNFT is a prototype implementation of the Adaptive NFT Collection standard.</p>
          <p>Adaptive collections are collections where the supply and rarity distribution are a function of the users' preferences and interactions, evolving over time.</p>
          <p>Rarity is organized into Levels.</p>
          <ul>
            <li>Level-0 NFTs are mintable by everyone (possibly with a date and supply limit).</li>
            <li>Higher levels are mintable by burning ("evolving") a certain number (here, 3) of NFTs of the previous level.</li>        
            <li>One can also downgrade an NFT into a certain number (here, 2) of NFTs of the previous level.</li>
            <li>SidesNFT assets get assigned a shape with a number of sides corresponding to their level, and with a random color. This behaviour can be customized and extended in various ways in the smart contract, for example using assignments based on user's holdings, possibly corresponding to IRL challenges.</li>
          </ul>
          <p>Once an exchange system is put in place (possibly even an IRL one), people can start hunting for the highest level assets, either for rewards or simple glory.</p>
        </div>
      </div>
    </div>
  )
}

