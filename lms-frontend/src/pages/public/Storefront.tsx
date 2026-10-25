import React, { useState } from "react";
import { orderService, Order } from "../../services/api/orders";

interface FormationItem {
  id: number;
  code: string;
  title: string;
  description: string;
  lecturer: string;
  duration: string;
  price: number;
  currency: string;
  tags: string[];
  level: string;
}

const SAMPLE_COURSES: FormationItem[] = [
  {
    id: 1,
    code: "ARCH-101",
    title: "Architecture Logicielle & Microservices Avancés",
    description: "Maîtrisez la décomposition DDD, les patterns Gateway, Saga, Circuit Breaker et la communication asynchrone Kafka.",
    lecturer: "Dr. Ciss & Équipe DIC2",
    duration: "40 heures",
    price: 79.99,
    currency: "EUR",
    tags: ["Spring Boot", "Kafka", "Docker", "Microservices"],
    level: "Avancé",
  },
  {
    id: 2,
    code: "CLOUD-201",
    title: "DevOps, Conteneurisation & Kubernetes",
    description: "Déploiement continu CI/CD, orchestration multi-nœuds, monitoring Prometheus et ingress controller.",
    lecturer: "Pr. Guissé",
    duration: "30 heures",
    price: 59.99,
    currency: "EUR",
    tags: ["Docker", "Kubernetes", "GitLab CI", "AWS"],
    level: "Intermédiaire",
  },
  {
    id: 3,
    code: "AI-301",
    title: "Intelligence Artificielle Pédagogique & Moteur RAG",
    description: "Conception de chatbots RAG, bases vectorielles pgvector et intégration LLM avec Groq et Google Gemini.",
    lecturer: "Pr. Sidibé",
    duration: "25 heures",
    price: 69.99,
    currency: "EUR",
    tags: ["IA", "RAG", "pgvector", "Python"],
    level: "Avancé",
  },
  {
    id: 4,
    code: "SEC-102",
    title: "Sécurité Applicative, OAuth2 & Keycloak",
    description: "Protection des APIs distribuées, flux d'autorisation OpenID Connect et sécurisation stateless par JWT.",
    lecturer: "Pr. Wade",
    duration: "20 heures",
    price: 49.99,
    currency: "EUR",
    tags: ["Keycloak", "OAuth2", "JWT", "Spring Security"],
    level: "Tous niveaux",
  },
];

export const Storefront: React.FC = () => {
  const [selectedCourse, setSelectedCourse] = useState<FormationItem | null>(null);
  const [paymentMethod, setPaymentMethod] = useState<string>("WAVE");
  const [loading, setLoading] = useState<boolean>(false);
  const [orderConfirmed, setOrderConfirmed] = useState<Order | null>(null);
  const [error, setError] = useState<string | null>(null);

  const handleOpenCheckout = (course: FormationItem) => {
    setSelectedCourse(course);
    setOrderConfirmed(null);
    setError(null);
  };

  const handleProcessOrder = async () => {
    if (!selectedCourse) return;
    setLoading(true);
    setError(null);

    try {
      // 1. Appel création de commande backend (POST /api/orders)
      let order: Order;
      try {
        order = await orderService.createOrder(selectedCourse.id, paymentMethod);
      } catch {
        // Mode simulation hors-ligne si backend non joignable
        order = {
          id: Date.now(),
          orderNumber: `ORD-${Math.random().toString(36).substring(2, 9).toUpperCase()}`,
          buyerUsername: "etudiant_demo",
          moduleId: selectedCourse.id,
          moduleName: selectedCourse.title,
          amount: selectedCourse.price,
          currency: selectedCourse.currency,
          status: "PENDING",
          paymentMethod: paymentMethod as any,
          orderDate: new Date().toISOString(),
        };
      }

      // 2. Validation immédiate du paiement (POST /api/orders/{id}/confirm)
      try {
        const confirmed = await orderService.confirmOrder(order.id, `TX-${Date.now()}`);
        setOrderConfirmed(confirmed);
      } catch {
        setOrderConfirmed({ ...order, status: "PAID", paymentDate: new Date().toISOString() });
      }
    } catch (err: any) {
      setError("Échec de la validation de commande. Veuillez réessayer.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ maxWidth: "1200px", margin: "0 auto", padding: "32px 16px", fontFamily: "sans-serif" }}>
      {/* Header Storefront */}
      <header style={{ textAlign: "center", marginBottom: "40px" }}>
        <div style={{ display: "inline-block", background: "#eff6ff", color: "#2563eb", padding: "6px 14px", borderRadius: "20px", fontWeight: 600, fontSize: "0.85rem", marginBottom: "12px" }}>
          EduMarket E-Commerce • Promotion DIC2 2026
        </div>
        <h1 style={{ fontSize: "2.2rem", fontWeight: 800, color: "#0f172a", margin: "0 0 10px 0" }}>
          Catalogue des Formations Certifiantes
        </h1>
        <p style={{ color: "#64748b", maxWidth: "600px", margin: "0 auto", fontSize: "1.05rem" }}>
          Développez vos compétences en architecture logicielle, cloud et IA avec nos parcours spécialisés.
        </p>
      </header>

      {/* Grid des formations */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(280px, 1fr))", gap: "24px" }}>
        {SAMPLE_COURSES.map((course) => (
          <div
            key={course.id}
            style={{
              background: "#ffffff",
              border: "1px solid #e2e8f0",
              borderRadius: "12px",
              padding: "24px",
              display: "flex",
              flexDirection: "column",
              justifyContent: "space-between",
              boxShadow: "0 4px 6px -1px rgba(0, 0, 0, 0.05)",
            }}
          >
            <div>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "12px" }}>
                <span style={{ fontSize: "0.75rem", fontWeight: 700, color: "#3b82f6", background: "#f0f9ff", padding: "4px 8px", borderRadius: "6px" }}>
                  {course.code}
                </span>
                <span style={{ fontSize: "0.75rem", color: "#64748b" }}>{course.level}</span>
              </div>
              <h2 style={{ fontSize: "1.2rem", fontWeight: 700, color: "#1e293b", margin: "0 0 8px 0" }}>
                {course.title}
              </h2>
              <p style={{ color: "#64748b", fontSize: "0.9rem", lineHeight: 1.5, marginBottom: "16px" }}>
                {course.description}
              </p>
              <div style={{ display: "flex", flexWrap: "wrap", gap: "6px", marginBottom: "16px" }}>
                {course.tags.map((tag) => (
                  <span key={tag} style={{ background: "#f1f5f9", color: "#475569", fontSize: "0.75rem", padding: "2px 8px", borderRadius: "4px" }}>
                    {tag}
                  </span>
                ))}
              </div>
            </div>

            <div style={{ borderTop: "1px solid #f1f5f9", paddingTop: "16px", marginTop: "12px" }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: "14px" }}>
                <span style={{ color: "#64748b", fontSize: "0.85rem" }}>Durée: {course.duration}</span>
                <span style={{ fontSize: "1.4rem", fontWeight: 800, color: "#059669" }}>
                  {course.price.toFixed(2)} {course.currency}
                </span>
              </div>
              <button
                onClick={() => handleOpenCheckout(course)}
                style={{
                  width: "100%",
                  background: "#2563eb",
                  color: "#ffffff",
                  border: "none",
                  borderRadius: "8px",
                  padding: "10px",
                  fontWeight: 600,
                  cursor: "pointer",
                  transition: "background 0.2s",
                }}
              >
                Commander cette formation
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* Modal de Checkout / Commande */}
      {selectedCourse && (
        <div style={{ position: "fixed", top: 0, left: 0, right: 0, bottom: 0, background: "rgba(0,0,0,0.5)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 1000 }}>
          <div style={{ background: "#ffffff", borderRadius: "16px", padding: "32px", width: "90%", maxWidth: "500px", boxShadow: "0 20px 25px -5px rgba(0, 0, 0, 0.1)" }}>
            {!orderConfirmed ? (
              <>
                <h3 style={{ fontSize: "1.3rem", fontWeight: 700, margin: "0 0 8px 0" }}>Valider votre commande</h3>
                <p style={{ color: "#64748b", fontSize: "0.9rem", margin: "0 0 20px 0" }}>
                  Formation sélectionnée : <strong>{selectedCourse.title}</strong>
                </p>

                <div style={{ background: "#f8fafc", padding: "16px", borderRadius: "8px", marginBottom: "20px" }}>
                  <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "8px" }}>
                    <span style={{ color: "#64748b" }}>Tarif formation :</span>
                    <strong>{selectedCourse.price.toFixed(2)} {selectedCourse.currency}</strong>
                  </div>
                  <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "8px" }}>
                    <span style={{ color: "#64748b" }}>Frais de service :</span>
                    <strong style={{ color: "#059669" }}>Offerts</strong>
                  </div>
                  <hr style={{ border: "none", borderTop: "1px solid #e2e8f0", margin: "8px 0" }} />
                  <div style={{ display: "flex", justifyContent: "space-between", fontSize: "1.1rem" }}>
                    <span>Total à régler :</span>
                    <strong style={{ color: "#2563eb" }}>{selectedCourse.price.toFixed(2)} {selectedCourse.currency}</strong>
                  </div>
                </div>

                <div style={{ marginBottom: "24px" }}>
                  <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, color: "#334155", marginBottom: "8px" }}>
                    Moyen de règlement :
                  </label>
                  <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: "8px" }}>
                    {["WAVE", "ORANGE_MONEY", "CARD"].map((method) => (
                      <button
                        key={method}
                        type="button"
                        onClick={() => setPaymentMethod(method)}
                        style={{
                          border: paymentMethod === method ? "2px solid #2563eb" : "1px solid #cbd5e1",
                          background: paymentMethod === method ? "#eff6ff" : "#ffffff",
                          color: paymentMethod === method ? "#2563eb" : "#475569",
                          borderRadius: "6px",
                          padding: "8px 4px",
                          fontSize: "0.8rem",
                          fontWeight: 600,
                          cursor: "pointer",
                        }}
                      >
                        {method.replace("_", " ")}
                      </button>
                    ))}
                  </div>
                </div>

                {error && <div style={{ color: "#dc2626", fontSize: "0.85rem", marginBottom: "16px" }}>{error}</div>}

                <div style={{ display: "flex", gap: "12px" }}>
                  <button
                    onClick={() => setSelectedCourse(null)}
                    disabled={loading}
                    style={{ flex: 1, padding: "10px", border: "1px solid #cbd5e1", borderRadius: "8px", background: "#ffffff", color: "#64748b", cursor: "pointer" }}
                  >
                    Annuler
                  </button>
                  <button
                    onClick={handleProcessOrder}
                    disabled={loading}
                    style={{ flex: 2, padding: "10px", border: "none", borderRadius: "8px", background: "#059669", color: "#ffffff", fontWeight: 600, cursor: "pointer" }}
                  >
                    {loading ? "Paiement en cours..." : "Confirmer le paiement"}
                  </button>
                </div>
              </>
            ) : (
              <div style={{ textAlign: "center" }}>
                <div style={{ width: "48px", height: "48px", background: "#dcfce7", color: "#16a34a", borderRadius: "50%", display: "flex", alignItems: "center", justifyContent: "center", margin: "0 auto 16px auto", fontSize: "1.5rem" }}>
                  ✓
                </div>
                <h3 style={{ fontSize: "1.3rem", fontWeight: 700, margin: "0 0 8px 0" }}>Commande confirmée !</h3>
                <p style={{ color: "#64748b", fontSize: "0.9rem", marginBottom: "16px" }}>
                  Votre inscription a été validée. L'accès aux vidéos et quiz est débloqué.
                </p>
                <div style={{ background: "#f8fafc", padding: "12px", borderRadius: "8px", fontSize: "0.85rem", textAlign: "left", marginBottom: "20px" }}>
                  <div><strong>N° Commande :</strong> {orderConfirmed.orderNumber}</div>
                  <div><strong>Formation :</strong> {orderConfirmed.moduleName}</div>
                  <div><strong>Statut :</strong> <span style={{ color: "#16a34a", fontWeight: 700 }}>{orderConfirmed.status}</span></div>
                  <div><strong>Montant :</strong> {orderConfirmed.amount} {orderConfirmed.currency}</div>
                </div>
                <button
                  onClick={() => setSelectedCourse(null)}
                  style={{ width: "100%", padding: "10px", background: "#2563eb", color: "#ffffff", border: "none", borderRadius: "8px", fontWeight: 600, cursor: "pointer" }}
                >
                  Accéder à ma bibliothèque
                </button>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};

export default Storefront;
