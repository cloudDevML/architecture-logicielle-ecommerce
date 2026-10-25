import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../../services/AuthContext';
import { useTheme } from '../../services/ThemeContext';
import apiPublic from '../../services/api/api-public';

const Login: React.FC = () => {
    const [username, setUsername] = useState('');
    const [password, setPassword] = useState('');
    const [showPw, setShowPw] = useState(false);
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);
    const { signIn } = useAuth();
    const { theme, toggleTheme } = useTheme();
    const navigate = useNavigate();

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        setLoading(true);
        try {
            const response = await apiPublic.post('/user/auth/login', { username, password });
            const { token, user, role } = response.data;
            signIn(token, user, role);
            if (role === 'ADMIN') navigate('/admin/index');
            else if (role === 'STUDENT') navigate('/student');
            else if (role === 'LECTURER') navigate('/lecturer');
            else navigate('/unauthorized');
        } catch (err: any) {
            if (err.response) {
                const status = err.response.status;
                const raw = err.response.data?.message || err.response.data?.error || err.response.data;
                const msg = typeof raw === 'string' ? raw : JSON.stringify(raw);
                if (status === 401) setError('Identifiants ou mot de passe invalides.');
                else if (status === 403) setError('Accès refusé. Compte non autorisé ou bloqué.');
                else if (status >= 500) setError('Erreur serveur (500). Le service utilisateur est peut-être hors-ligne.');
                else setError(msg || `Erreur ${status} lors de la connexion.`);
            } else if (err.request) {
                setError('Le serveur ne répond pas. Vérifiez que les microservices sont lancés.');
            } else {
                setError('Une erreur est survenue lors de la connexion.');
            }
        } finally {
            setLoading(false);
        }
    };

    const S = styles;

    return (
        <div style={S.page}>
            {/* Left panel */}
            <div style={S.left}>
                <div style={S.leftInner}>
                    <div style={S.logo}>
                        <span style={S.logoIcon}><i className="fas fa-terminal" /></span>
                        <span style={S.logoText}>EPT<span style={S.logoAccent}>LMS</span></span>
                    </div>
                    <p style={S.tagline}>Système de gestion de l'apprentissage nouvelle génération</p>

                    <div style={S.divider} />

                    <div style={S.features}>
                        {[
                            { icon: 'fa-book-open',    text: 'Gestion complète des modules et cours' },
                            { icon: 'fa-comments',     text: 'Collaboration interactive et mentorat' },
                            { icon: 'fa-chart-bar',    text: 'Évaluation continue et suivi académique' },
                            { icon: 'fa-tasks',        text: 'Ressources pédagogiques dynamiques' },
                        ].map((f, i) => (
                            <div key={i} style={S.feature}>
                                <i className={`fas ${f.icon}`} style={S.featureIcon} />
                                <span style={S.featureText}>{f.text}</span>
                            </div>
                        ))}
                    </div>

                    <div style={S.leftFooter}>
                        &copy; {new Date().getFullYear()} EPT &mdash; Plateforme LMS
                    </div>
                </div>
            </div>

            {/* Right panel */}
            <div style={S.right} className="login-right">
                <div style={S.card} className="login-card">
                    <div style={S.cardTop}>
                        <h2 style={S.title}>Connexion</h2>
                        <p style={S.subtitle}>Entrez vos identifiants pour continuer</p>
                    </div>

                    {error && (
                        <div style={S.errorBox} role="alert" aria-live="polite" id="login-error">
                            <i className="fas fa-exclamation-triangle" style={{ marginRight: '.5rem', color: '#ff3e3e' }} aria-hidden="true" />
                            <span>{error}</span>
                        </div>
                    )}

                    <form onSubmit={handleSubmit} noValidate>
                        <div style={S.field}>
                            <label htmlFor="username" style={S.label}>Adresse Email</label>
                            <div style={S.inputRow}>
                                <i className="fas fa-envelope" style={S.inputIco} aria-hidden="true" />
                                <input
                                    id="username"
                                    type="text"
                                    style={S.input}
                                    placeholder="Identifiant ou email"
                                    value={username}
                                    onChange={e => setUsername(e.target.value)}
                                    required
                                    autoFocus
                                    aria-invalid={!!error}
                                    aria-describedby={error ? "login-error" : undefined}
                                />
                            </div>
                        </div>

                        <div style={S.field}>
                            <label htmlFor="password" style={S.label}>Mot de passe</label>
                            <div style={S.inputRow}>
                                <i className="fas fa-lock" style={S.inputIco} aria-hidden="true" />
                                <input
                                    id="password"
                                    type={showPw ? 'text' : 'password'}
                                    style={S.input}
                                    placeholder="••••••••"
                                    value={password}
                                    onChange={e => setPassword(e.target.value)}
                                    required
                                    aria-invalid={!!error}
                                />
                                <button 
                                    type="button" 
                                    style={S.eyeBtn} 
                                    onClick={() => setShowPw(v => !v)}
                                    aria-label={showPw ? "Masquer le mot de passe" : "Afficher le mot de passe"}
                                    aria-pressed={showPw}
                                >
                                    <i className={`fas ${showPw ? 'fa-eye-slash' : 'fa-eye'}`} aria-hidden="true" />
                                </button>
                            </div>
                        </div>

                        <button
                            type="submit"
                            style={{ ...S.submitBtn, ...(loading ? S.submitDisabled : {}) }}
                            disabled={loading}
                            aria-busy={loading}
                        >
                            {loading ? (
                                <><span className="login-spinner" aria-hidden="true" /> <span>Connexion...</span></>
                            ) : (
                                <><i className="fas fa-sign-in-alt" style={{ marginRight: '.5rem' }} aria-hidden="true" />Se connecter</>
                            )}
                        </button>
                    </form>

                    <div style={{ marginTop: '1.2rem', textAlign: 'center' }}>
                        <a
                            href="/store"
                            style={{
                                display: 'inline-block',
                                padding: '8px 16px',
                                background: '#eff6ff',
                                color: '#2563eb',
                                borderRadius: '8px',
                                textDecoration: 'none',
                                fontWeight: 600,
                                fontSize: '0.9rem',
                                border: '1px solid #bfdbfe'
                            }}
                        >
                            🛒 Explorer le Catalogue E-Commerce (EduMarket)
                        </a>
                    </div>

                    <div style={{ marginTop: '1.5rem', display: 'flex', justifyContent: 'center' }}>
                        <button
                            type="button"
                            onClick={toggleTheme}
                            style={{
                                background: 'var(--bg-elevated)',
                                border: '1px solid var(--border)',
                                borderRadius: '20px',
                                padding: '6px 16px',
                                cursor: 'pointer',
                                display: 'flex',
                                alignItems: 'center',
                                gap: '8px',
                                fontSize: '.8rem',
                                fontWeight: 600,
                                color: 'var(--text-secondary)',
                                transition: 'var(--t)'
                            }}
                        >
                            <i className={`fas ${theme === 'light' ? 'fa-moon' : 'fa-sun'}`} />
                            Mode {theme === 'light' ? 'Sombre' : 'Clair'}
                        </button>
                    </div>
                </div>
            </div>

            <style>{`
                @keyframes login-spin {
                    to { transform: rotate(360deg); }
                }
                .login-spinner {
                    width: 16px; height: 16px;
                    border: 2px solid rgba(255,255,255,.3);
                    border-top-color: #ffffff;
                    border-radius: 50%;
                    animation: login-spin .7s linear infinite;
                }
                @media (max-width: 992px) {
                    div[style*="flex: 0 0 40%"] {
                        display: none !important;
                    }
                    .login-right {
                        padding: 1.5rem !important;
                    }
                    .login-card {
                        max-width: 100% !important;
                        box-shadow: none !important;
                        border: none !important;
                        background: transparent !important;
                        padding: 1rem !important;
                    }
                }
            `}</style>
        </div>
    );
};

const styles: Record<string, React.CSSProperties> = {
    page: {
        display: 'flex', minHeight: '100vh',
        fontFamily: "'Inter', sans-serif",
        background: 'var(--bg-elevated)',
    },
    left: {
        flex: '0 0 40%',
        background: 'var(--bg-card)',
        borderRight: '1px solid var(--border)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '3rem',
        position: 'relative',
    },
    leftInner: { width: '100%', maxWidth: 340 },
    logo: {
        display: 'flex', alignItems: 'center', gap: '1rem', marginBottom: '1rem',
    },
    logoIcon: {
        width: 44, height: 44, borderRadius: 6,
        background: 'var(--accent-light)',
        border: '1px solid var(--accent-border)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: 'var(--accent)', fontSize: '1.1rem',
    } as any,
    logoText: {
        fontSize: '1.5rem', fontWeight: 800, color: 'var(--text-primary)',
        letterSpacing: '.5px',
    },
    logoAccent: { color: 'var(--accent)', marginLeft: 4 },
    tagline: { color: 'var(--text-secondary)', fontSize: '.875rem', fontWeight: 500, margin: 0 },
    divider: { height: 1, background: 'var(--border)', margin: '1.75rem 0' },
    features: { display: 'flex', flexDirection: 'column', gap: '.9rem', marginBottom: '2.5rem' },
    feature: { display: 'flex', alignItems: 'center', gap: '.85rem' },
    featureIcon: { color: 'var(--accent)', fontSize: '.85rem', width: 16, textAlign: 'center' },
    featureText: { color: 'var(--text-primary)', fontSize: '.875rem', fontWeight: 500 },
    leftFooter: {
        position: 'absolute', bottom: '1.5rem', left: '3rem',
        color: 'var(--text-muted)', fontSize: '.75rem', display: 'flex', alignItems: 'center',
    } as any,
    right: {
        flex: 1, display: 'flex',
        alignItems: 'center', justifyContent: 'center',
        padding: '2rem', background: 'var(--bg-elevated)',
    },
    card: {
        background: 'var(--bg-card)',
        border: '1px solid var(--border)',
        borderRadius: 12,
        padding: '2.25rem',
        width: '100%', maxWidth: 400,
        boxShadow: 'var(--shadow-lg)',
    },
    cardTop: { marginBottom: '1.75rem' },
    title: { fontSize: '1.5rem', fontWeight: 800, color: 'var(--text-primary)', margin: '0 0 .35rem' },
    subtitle: { color: 'var(--text-secondary)', fontSize: '.875rem', margin: 0 },
    errorBox: {
        background: 'rgba(220,38,38,.06)',
        border: '1px solid rgba(220,38,38,.2)',
        borderLeft: '3px solid var(--danger)',
        borderRadius: 6,
        padding: '.7rem 1rem',
        color: 'var(--danger)',
        fontSize: '.84rem',
        fontWeight: 500,
        marginBottom: '1.1rem',
        display: 'flex', alignItems: 'center',
    },
    field: { display: 'flex', flexDirection: 'column', marginBottom: '1.25rem' },
    label: {
        fontSize: '.72rem', fontWeight: 800, color: 'var(--text-primary)',
        textTransform: 'uppercase', letterSpacing: '.6px', marginBottom: '.4rem',
    } as any,
    inputRow: { position: 'relative', display: 'flex', alignItems: 'center' },
    inputIco: {
        position: 'absolute', left: '.85rem',
        color: 'var(--text-muted)', fontSize: '.8rem', pointerEvents: 'none',
    } as any,
    input: {
        width: '100%',
        padding: '.7rem .9rem .7rem 2.4rem',
        background: 'var(--bg-input)',
        border: '1px solid var(--border)',
        borderRadius: 6,
        color: 'var(--text-primary)',
        fontSize: '.875rem',
        fontFamily: "'Inter', sans-serif",
        outline: 'none',
        transition: 'var(--t)',
    },
    eyeBtn: {
        position: 'absolute', right: '.85rem',
        background: 'none', border: 'none', cursor: 'pointer',
        color: 'var(--text-muted)', padding: 0, fontSize: '.85rem',
    } as any,
    submitBtn: {
        width: '100%', marginTop: '.5rem',
        padding: '.75rem',
        background: 'var(--accent)',
        border: 'none',
        borderRadius: 6,
        color: '#ffffff',
        fontSize: '.9rem',
        fontWeight: 700,
        cursor: 'pointer',
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '.4rem',
        fontFamily: "'Inter', sans-serif",
        transition: 'all .2s',
        boxShadow: '0 4px 6px -1px rgba(37, 99, 235, 0.2)',
    },
    submitDisabled: { opacity: .7, cursor: 'not-allowed' },
    spinner: {
        width: 16, height: 16,
        border: '2px solid rgba(255,255,255,.3)',
        borderTopColor: '#ffffff',
        borderRadius: '50%',
        animation: 'spin .7s linear infinite',
    },
};

export default Login;
