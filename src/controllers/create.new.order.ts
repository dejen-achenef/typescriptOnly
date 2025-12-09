import { Request, Response } from "express";
import prisma from "../prisma/client";
import { OrderValidator } from "../validators/Order.validator";

export const createNewOrder = async (req: Request, res: Response) => {
  // Validate request body
  const { value, error } = OrderValidator.validate(req.body);
  if (error) {
    return res.status(400).json({ errors: error.details });
  }

  const { items } = value;
  const userId = (req as any).user?.id;

  if (!userId) {
    return res.status(401).json({ error: "User not authenticated" });
  }

  // Verify user has 'User' role
  const user = await prisma.user.findUnique({
    where: { id: userId },
  });

  if (!user) {
    return res.status(401).json({ error: "User not found" });
  }

  if ((user as any).role && (user as any).role !== "User") {
    return res.status(403).json({ error: "Access denied. Only users with 'User' role can place orders." });
  }

  try {
    // Use transaction to ensure atomicity
    const result = await prisma.$transaction(async (tx) => {
      // Step 1: Fetch all products and validate stock
      const productIds = items.map((item: any) => item.productId);
      const products = await tx.product.findMany({
        where: {
          id: { in: productIds },
        },
      });

      // Check if all products exist
      if (products.length !== productIds.length) {
        const foundIds = new Set(products.map((p) => p.id));
        const missingIds = productIds.filter((id: string) => !foundIds.has(id));
        throw new Error(`Products not found: ${missingIds.join(", ")}`);
      }

      // Step 2: Validate stock and calculate total price
      let totalPrice = 0;
      const stockChecks: Array<{ product: any; requestedQuantity: number }> = [];

      for (const item of items) {
        const product = products.find((p) => p.id === item.productId);
        if (!product) {
          throw new Error(`Product ${item.productId} not found`);
        }

        if (product.stock < item.quantity) {
          throw new Error(`Insufficient stock for ${product.name}. Available: ${product.stock}, Requested: ${item.quantity}`);
        }

        totalPrice += product.price * item.quantity;
        stockChecks.push({ product, requestedQuantity: item.quantity });
      }

      // Step 3: Create order
      const order = await tx.order.create({
        data: {
          userId,
          description: "New Order",
          totalPrice,
          status: "pending",
        },
      });

      // Step 4: Create order items and update stock
      await Promise.all(
        stockChecks.map(async ({ product, requestedQuantity }) => {
          // Create order item
          await tx.orderItem.create({
            data: {
              orderId: order.id,
              productId: product.id,
              quantity: requestedQuantity,
            },
          });

          // Update product stock
          await tx.product.update({
            where: { id: product.id },
            data: {
              stock: {
                decrement: requestedQuantity,
              },
            },
          });
        })
      );

      // Step 5: Fetch complete order with items
      const completeOrder = await tx.order.findUnique({
        where: { id: order.id },
        include: {
          orderItems: {
            include: {
              product: {
                select: {
                  id: true,
                  name: true,
                  price: true,
                  description: true,
                },
              },
            },
          },
        },
      });

      return completeOrder;
    });

    return res.status(201).json({
      success: true,
      message: "Order created successfully",
      order: {
        order_id: result!.id,
        status: result!.status,
        total_price: result!.totalPrice,
        products: result!.orderItems.map((item) => ({
          productId: item.productId,
          name: item.product.name,
          price: item.product.price,
          quantity: item.quantity,
        })),
      },
    });
  } catch (error: any) {
    // Check if it's a stock validation error
    if (error.message.includes("Insufficient stock") || error.message.includes("not found")) {
      return res.status(400).json({
        success: false,
        error: error.message,
      });
    }

    console.error("Order creation error:", error);
    return res.status(500).json({
      success: false,
      error: "Failed to create order",
      message: error.message,
    });
  }
};