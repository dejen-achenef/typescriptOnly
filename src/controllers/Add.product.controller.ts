import { Request, Response } from "express";
import { PostValidator } from "../validators/Post.validator";
import prisma from "../prisma/client";

export const AddPost = async (req: Request, res: Response) => {
  const { value, error } = PostValidator.validate(req.body);
  if (error) {
    return res.status(400).json({ errors: error.details });
  }

  const { name, description, price, stock, category } = value;
  
  // Get userId from request (assuming it's set by auth middleware)
  const userId = (req as any).user?.id;
  if (!userId) {
    return res.status(401).json({ error: "User not authenticated" });
  }

  try {
    const post = await prisma.product.create({
      data: {
        name,
        description,
        price,
        stock,
        category,
        userId,
      },
    });
    return res.status(201).json(post);
  } catch (error: any) {
    return res.status(500).json({ error: "Failed to create product", message: error.message });
  }
};