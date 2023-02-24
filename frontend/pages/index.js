import Head from 'next/head'
import Main from '../components/Main'
import Script from 'next/script'

export default function Home() {
  return (
    <div>
      <Head>
        <title>SidesNFT</title>
        <meta name="description" content="SidesNFT app" />
        <link rel="icon" href="/thumbnail.png" />
        <meta property="og:image" content="/thumbnail.png" />
      </Head>

      <main>
        <div className="grid">
          <Main />
        </div>
      </main>

    </div>
  )
}
