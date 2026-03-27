import { useState, useEffect, useCallback, useRef } from 'react'
import { ethers } from 'ethers'

const ForumABI = [
  'event PostCreated(address indexed author, uint indexed postId, uint created_at)',
  'event PostRemoved(address indexed author, uint indexed postId, uint removed_at)',
  'event PostsCleared(uint indexed timestamp, uint post_count)',
  'event PostLiked(address indexed user, uint indexed postId, uint likeCount)',
  'event PostUnliked(address indexed user, uint indexed postId, uint likeCount)',
  'function create_post(string calldata message) external',
  'function remove_post(uint idx) external',
  'function like_post(uint idx) external',
  'function unlike_post(uint idx) external',
  'function get_posts() external view returns ((string message, address author, uint created_at, uint like, bool exists)[] memory)',
  'function has_liked(uint idx) external view returns (bool)',
]

/** Фільтр: усі пости | лише мої | конкретна адреса автора */
const FILTER_ALL = 'all'
const FILTER_ME = 'me'
const FILTER_ADDRESS = 'address'

function App() {
  const [account, setAccount] = useState(null)
  const [balance, setBalance] = useState(null)
  const [contract, setContract] = useState(null)
  const [posts, setPosts] = useState([])
  const [newMessage, setNewMessage] = useState('')
  const [loading, setLoading] = useState(false)
  const [filterMode, setFilterMode] = useState(FILTER_ALL)
  const [authorAddressInput, setAuthorAddressInput] = useState('')

  const contractRef = useRef(null)

  const loadContractAddress = async () => {
    try {
      const response = await fetch('/contract-addresses.json')
      const data = await response.json()
      return data.forum ?? null
    } catch (err) {
      console.error('contract-addresses.json:', err)
      return null
    }
  }

  const loadPosts = useCallback(async (forumContract) => {
    const c = forumContract ?? contractRef.current
    if (!c) return
    try {
      setLoading(true)
      const postsData = await c.get_posts()
      const postsWithLikeStatus = await Promise.all(
        postsData.map(async (post, idx) => {
          const hasLiked = await c.has_liked(idx)
          return {
            id: idx,
            message: post.message,
            author: post.author,
            createdAt: new Date(Number(post.created_at) * 1000).toLocaleString(),
            likes: Number(post.like),
            exists: post.exists,
            hasLiked,
          }
        })
      )
      setPosts(postsWithLikeStatus)
    } catch (err) {
      console.error('loadPosts:', err)
    } finally {
      setLoading(false)
    }
  }, [])

  const subscribeToEvents = useCallback(
    (forumContract) => {
      forumContract.removeAllListeners()
      const rerender = () => loadPosts(forumContract)

      forumContract.on('PostCreated', rerender)
      forumContract.on('PostRemoved', rerender)
      forumContract.on('PostLiked', rerender)
      forumContract.on('PostUnliked', rerender)
      forumContract.on('PostsCleared', rerender)
    },
    [loadPosts]
  )

  const attachContract = useCallback(
    async (contractAddr) => {
      contractRef.current?.removeAllListeners()
      const provider = new ethers.BrowserProvider(window.ethereum)
      const signer = await provider.getSigner()
      const forumContract = new ethers.Contract(contractAddr, ForumABI, signer)
      contractRef.current = forumContract
      setContract(forumContract)
      await loadPosts(forumContract)
      subscribeToEvents(forumContract)
    },
    [loadPosts, subscribeToEvents]
  )

  const refreshWallet = useCallback(async (addr) => {
    const provider = new ethers.BrowserProvider(window.ethereum)
    const bal = await provider.getBalance(addr)
    setBalance(ethers.formatEther(bal))
  }, [])

  const connectWallet = async () => {
    if (!window.ethereum) {
      alert('Встановіть MetaMask!')
      return
    }
    const contractAddr = await loadContractAddress()
    if (!contractAddr) {
      alert('Спочатку задеплойте контракт (npm run deploy:forum) і перевірте public/contract-addresses.json')
      return
    }
    try {
      const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' })
      const acc = accounts[0]
      setAccount(acc)
      await refreshWallet(acc)
      await attachContract(contractAddr)
    } catch (err) {
      console.error(err)
    }
  }

  useEffect(() => {
    let cancelled = false
    ;(async () => {
      if (!window.ethereum) return
      const contractAddr = await loadContractAddress()
      if (!contractAddr || cancelled) return
      const provider = new ethers.BrowserProvider(window.ethereum)
      const accounts = await provider.listAccounts()
      if (accounts.length === 0 || cancelled) return
      const acc =
        typeof accounts[0] === 'string' ? accounts[0] : accounts[0].address ?? accounts[0]
      setAccount(acc)
      const bal = await provider.getBalance(acc)
      if (!cancelled) setBalance(ethers.formatEther(bal))
      if (!cancelled) await attachContract(contractAddr)
    })()
    return () => {
      cancelled = true
      contractRef.current?.removeAllListeners()
      contractRef.current = null
    }
  }, [attachContract])

  const handleCreatePost = async () => {
    if (!newMessage.trim() || !contract) return
    try {
      const tx = await contract.create_post(newMessage.trim())
      await tx.wait()
      setNewMessage('')
    } catch (err) {
      console.error(err)
      alert('Помилка: ' + err.message)
    }
  }

  const handleRemovePost = async (postId) => {
    if (!contract) return
    try {
      const tx = await contract.remove_post(postId)
      await tx.wait()
    } catch (err) {
      console.error(err)
      alert('Помилка видалення: ' + err.message)
    }
  }

  const handleToggleLike = async (post) => {
    if (!contract) return
    try {
      const tx = post.hasLiked
        ? await contract.unlike_post(post.id)
        : await contract.like_post(post.id)
      await tx.wait()
    } catch (err) {
      console.error(err)
      alert('Помилка лайку: ' + err.message)
    }
  }

  const isValidEthAddress = (s) => /^0x[a-fA-F0-9]{40}$/.test(s?.trim() ?? '')

  const filteredPosts = posts.filter((post) => {
    if (!post.exists) return false
    if (filterMode === FILTER_ALL) return true
    if (filterMode === FILTER_ME) {
      return account && post.author.toLowerCase() === account.toLowerCase()
    }
    if (filterMode === FILTER_ADDRESS) {
      const target = authorAddressInput.trim()
      if (!isValidEthAddress(target)) return false
      return post.author.toLowerCase() === target.toLowerCase()
    }
    return true
  })

  const filterTitle =
    filterMode === FILTER_ALL
      ? 'Усі пости'
      : filterMode === FILTER_ME
        ? 'Мої пости'
        : 'Пости автора'

  return (
    <div style={styles.container}>
      <header style={styles.header}>
        <h1 style={styles.title}>Crypta Forum</h1>
        <p style={styles.subtitle}>Децентралізований форум (Lesson 8)</p>
      </header>

      {!account ? (
              <button type="button" className="connectButton" onClick={connectWallet} style={styles.connectButton}>
          Підключити MetaMask
        </button>
      ) : (
        <>
          <section style={styles.walletInfo} aria-label="Гаманець">
            <p>
              <strong>Адреса:</strong> {account.slice(0, 6)}…{account.slice(-4)}
            </p>
            <p>
              <strong>Баланс:</strong> {balance} ETH
            </p>
          </section>

          <section style={styles.createPostSection} aria-label="Новий пост">
            <h2 style={styles.sectionTitle}>Створити пост</h2>
            <div style={styles.createPostForm}>
              <textarea
                value={newMessage}
                onChange={(e) => setNewMessage(e.target.value)}
                placeholder="Текст посту…"
                style={styles.textarea}
                rows={3}
              />
              <button type="button" className="createButton" onClick={handleCreatePost} style={styles.createButton}>
                Опублікувати
              </button>
            </div>
          </section>

          <section style={styles.filterSection} aria-label="Фільтр автора">
            <label htmlFor="filterMode" style={styles.filterLabel}>
              Показати:
            </label>
            <select
              id="filterMode"
              value={filterMode}
              onChange={(e) => setFilterMode(e.target.value)}
              style={styles.filterSelect}
            >
              <option value={FILTER_ALL}>Усі пости</option>
              <option value={FILTER_ME}>Лише мої пости</option>
              <option value={FILTER_ADDRESS}>Конкретний автор (адреса)</option>
            </select>
            {filterMode === FILTER_ADDRESS && (
              <input
                type="text"
                value={authorAddressInput}
                onChange={(e) => setAuthorAddressInput(e.target.value)}
                placeholder="0x… адреса автора"
                style={styles.authorInput}
              />
            )}
          </section>

          <section style={styles.postsSection} aria-label="Список постів">
            <h2 style={styles.sectionTitle}>
              {filterTitle} ({filteredPosts.length})
            </h2>

            {loading && <p style={styles.loading}>Завантаження…</p>}

            {!loading && filteredPosts.length === 0 && (
              <p style={styles.noPosts}>Немає постів за цим фільтром</p>
            )}

            <div style={styles.postsGrid}>
              {filteredPosts.map((post) => (
                <article key={post.id} className="postCard" style={styles.postCard}>
                  <div style={styles.postHeader}>
                    <span style={styles.postAuthor}>
                      {post.author.slice(0, 6)}…{post.author.slice(-4)}
                    </span>
                    <time style={styles.postDate} dateTime={String(post.createdAt)}>
                      {post.createdAt}
                    </time>
                  </div>
                  <p style={styles.postMessage}>{post.message}</p>
                  <div style={styles.postFooter}>
                    <button
                      type="button"
                      className="likeButton"
                      onClick={() => handleToggleLike(post)}
                      style={{
                        ...styles.likeButton,
                        background: post.hasLiked ? '#be123c' : '#3f3f46',
                      }}
                    >
                      {post.hasLiked ? '♥' : '♡'} {post.likes}
                    </button>
                    {account && post.author.toLowerCase() === account.toLowerCase() && (
                      <button
                        type="button"
                        className="deleteButton"
                        onClick={() => handleRemovePost(post.id)}
                        style={styles.deleteButton}
                      >
                        Видалити
                      </button>
                    )}
                  </div>
                </article>
              ))}
            </div>
          </section>
        </>
      )}
    </div>
  )
}

const styles = {
  container: {
    maxWidth: 900,
    margin: '0 auto',
    padding: '2rem',
    minHeight: '100vh',
  },
  header: { textAlign: 'center', marginBottom: '2rem' },
  title: {
    fontSize: '2.25rem',
    background: 'linear-gradient(135deg, #6366f1, #a78bfa)',
    WebkitBackgroundClip: 'text',
    backgroundClip: 'text',
    WebkitTextFillColor: 'transparent',
    marginBottom: '0.5rem',
  },
  subtitle: { color: '#a1a1aa', fontSize: '1rem' },
  connectButton: {
    display: 'block',
    margin: '2rem auto',
    padding: '14px 28px',
    fontSize: 17,
    fontWeight: 600,
    background: 'linear-gradient(135deg, #6366f1, #7c3aed)',
    color: '#fff',
    border: 'none',
    borderRadius: 12,
    cursor: 'pointer',
  },
  walletInfo: {
    background: '#18181b',
    padding: '1.25rem 1.5rem',
    borderRadius: 12,
    marginBottom: '1.5rem',
    border: '1px solid #27272a',
  },
  createPostSection: {
    background: '#18181b',
    padding: '1.5rem',
    borderRadius: 12,
    marginBottom: '1.5rem',
    border: '1px solid #27272a',
  },
  sectionTitle: {
    fontSize: '1.25rem',
    marginBottom: '1rem',
    color: '#fafafa',
  },
  createPostForm: { display: 'flex', flexDirection: 'column', gap: '1rem' },
  textarea: {
    padding: '1rem',
    fontSize: 16,
    background: '#09090b',
    border: '1px solid #3f3f46',
    borderRadius: 10,
    color: '#fafafa',
    resize: 'vertical',
    fontFamily: 'inherit',
  },
  createButton: {
    alignSelf: 'flex-start',
    padding: '12px 24px',
    fontSize: 15,
    fontWeight: 600,
    background: 'linear-gradient(135deg, #059669, #047857)',
    color: '#fff',
    border: 'none',
    borderRadius: 10,
    cursor: 'pointer',
  },
  filterSection: {
    display: 'flex',
    flexWrap: 'wrap',
    alignItems: 'center',
    gap: '0.75rem',
    marginBottom: '1.5rem',
  },
  filterLabel: { color: '#a1a1aa', fontSize: 15 },
  filterSelect: {
    padding: '10px 14px',
    fontSize: 15,
    background: '#18181b',
    border: '1px solid #3f3f46',
    borderRadius: 10,
    color: '#fafafa',
    cursor: 'pointer',
  },
  authorInput: {
    flex: '1 1 220px',
    minWidth: 200,
    padding: '10px 12px',
    fontSize: 14,
    fontFamily: 'monospace',
    background: '#09090b',
    border: '1px solid #3f3f46',
    borderRadius: 10,
    color: '#fafafa',
  },
  postsSection: {
    background: '#18181b',
    padding: '1.5rem',
    borderRadius: 12,
    border: '1px solid #27272a',
  },
  postsGrid: { display: 'grid', gap: '1.25rem', marginTop: '1rem' },
  postCard: {
    background: '#09090b',
    padding: '1.25rem 1.5rem',
    borderRadius: 12,
    border: '1px solid #27272a',
    boxShadow: '0 4px 24px rgba(0,0,0,0.35)',
  },
  postHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '0.75rem',
    flexWrap: 'wrap',
    gap: '0.5rem',
  },
  postAuthor: { color: '#818cf8', fontWeight: 600, fontSize: 13 },
  postDate: { color: '#71717a', fontSize: 12 },
  postMessage: {
    color: '#e4e4e7',
    fontSize: 16,
    lineHeight: 1.6,
    marginBottom: '1rem',
    wordBreak: 'break-word',
  },
  postFooter: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: '0.75rem',
    paddingTop: '0.75rem',
    borderTop: '1px solid #27272a',
  },
  likeButton: {
    padding: '8px 16px',
    fontSize: 14,
    fontWeight: 600,
    color: '#fff',
    border: 'none',
    borderRadius: 8,
    cursor: 'pointer',
  },
  deleteButton: {
    padding: '8px 14px',
    fontSize: 13,
    fontWeight: 600,
    background: '#b91c1c',
    color: '#fff',
    border: 'none',
    borderRadius: 8,
    cursor: 'pointer',
  },
  loading: { textAlign: 'center', color: '#a1a1aa', padding: '2rem' },
  noPosts: { textAlign: 'center', color: '#71717a', padding: '2rem' },
}

export default App
