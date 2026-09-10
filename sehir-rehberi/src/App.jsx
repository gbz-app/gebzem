export default function App() {
  return (
    <main
      style={{
        maxWidth: 560,
        margin: '0 auto',
        padding: '48px 16px',
      }}
    >
      <p
        style={{
          margin: 0,
          fontSize: 13,
          fontWeight: 700,
          letterSpacing: 0,
          color: 'var(--vurgu)',
        }}
      >
        İSKELET HAZIR
      </p>

      <h1 style={{ margin: '8px 0 12px', fontSize: 30, lineHeight: 1.15 }}>
        Şehir Rehberi
      </h1>

      <p style={{ margin: 0, fontSize: 16, lineHeight: 1.55, color: 'var(--yazi-soluk)' }}>
        React 18 + Vite kurulu ve çalışıyor. Ekranlar (anasayfa, kategori
        listesi, mekân detayı, harita) kapsam kararından sonra eklenecek.
      </p>

      <div
        style={{
          marginTop: 28,
          padding: 16,
          background: 'var(--yuzey)',
          border: '1px solid var(--kenar)',
          borderRadius: 'var(--yaricap)',
          fontSize: 14,
          lineHeight: 1.6,
        }}
      >
        <strong style={{ display: 'block', marginBottom: 6 }}>Çalıştırmak için</strong>
        <code style={{ fontSize: 13 }}>npm install</code>
        <br />
        <code style={{ fontSize: 13 }}>npm run dev</code>
      </div>
    </main>
  )
}
