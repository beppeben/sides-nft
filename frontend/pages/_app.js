import '@picocss/pico'
import '../styles/globals.css'
import Link from 'next/link'
import { ThemeProvider } from 'next-themes'

function MyApp({ Component, pageProps }) {
  return(
  <ThemeProvider defaultTheme="light">    
    <div>
    <nav className="container header">
      <ul>
        <li>
          <div>
            <Link href="/">
              <a><h2>SidesNFT</h2></a>
            </Link>
          </div>
          <span className="subHeader"><small>Flow Hackathon 2023</small></span>
        </li>
      </ul>
    </nav>
    <main className="container">
      <Component {...pageProps} />
    </main>
    <footer className="container">
      <nav className="container header center">
        <ul>
          <li>
            <a href="https://flow-view-source.com/mainnet/account/0x1600b04bf033fb99/contract/DayNFT" target="_blank" rel="noopener noreferrer">GitHub</a>
          </li>
        </ul>
      </nav>
    </footer>
    </div>
  </ThemeProvider>)
}

export default MyApp
