import api from "./api";

export interface Order {
  id: number;
  orderNumber: string;
  buyerUsername: string;
  moduleId: number;
  moduleName: string;
  amount: number;
  currency: string;
  status: "PENDING" | "PAID" | "CANCELLED" | "REFUNDED";
  paymentMethod: "CARD" | "WAVE" | "ORANGE_MONEY" | "SIMULATED";
  transactionId?: string;
  orderDate: string;
  paymentDate?: string;
}

export interface CreateOrderRequest {
  moduleId: number;
  paymentMethod?: string;
}

export const orderService = {
  // Créer une commande de formation (état PENDING)
  createOrder: async (moduleId: number, paymentMethod: string = "WAVE"): Promise<Order> => {
    const response = await api.post<Order>("/orders", { moduleId, paymentMethod });
    return response.data;
  },

  // Confirmer le règlement et débloquer la formation (état PAID)
  confirmOrder: async (orderId: number, transactionId?: string): Promise<Order> => {
    const response = await api.post<Order>(`/orders/${orderId}/confirm`, {
      transactionId: transactionId || `TX-${Date.now()}`,
    });
    return response.data;
  },

  // Récupérer la liste des commandes du client connecté
  getMyOrders: async (): Promise<Order[]> => {
    const response = await api.get<Order[]>("/orders/my-orders");
    return response.data;
  },

  // Récupérer le reçu détaillé d'une commande
  getOrderById: async (orderId: number): Promise<Order> => {
    const response = await api.get<Order>(`/orders/${orderId}`);
    return response.data;
  },

  // Récupérer toutes les commandes (administrateur)
  getAllOrders: async (): Promise<Order[]> => {
    const response = await api.get<Order[]>("/orders");
    return response.data;
  },
};
