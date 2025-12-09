import { Request, Response } from "express";
import prisma from "../prisma/client";

export const getOrderHistory = async (req: Request, res: Response) => {
  const userId = (req as any).user?.id;

  if (!userId) {
    return res.status(401).json({ error: "Unauthorized - User not authenticated" });
  }

  try {
    // Fetch all orders for the authenticated user
    const orders = await prisma.order.findMany({
      where: {
        userId: userId,
      },
      include: {
        orderItems: {
          include: {
            product: {
              select: {
                id: true,
                name: true,
                price: true,
              },
            },
          },
        },
      },
      orderBy: {
        // Order by most recent first (if createdAt exists) or by id
        id: "desc",
      },
    });

    // Format the response with required fields
    const formattedOrders = orders.map((order) => ({
      order_id: order.id,
      status: order.status,
      total_price: order.totalPrice,
      // Note: createdAt is not in the schema. To add it, update prisma/schema.prisma:
      // createdAt DateTime @default(now())
      // Then run: npx prisma migrate dev
    }));

    return res.status(200).json({
      success: true,
      orders: formattedOrders,
      count: formattedOrders.length,
    });
  } catch (error: any) {
    console.error("Error fetching order history:", error);
    return res.status(500).json({
      success: false,
      error: "Failed to fetch order history",
      message: error.message,
    });
  }
};

