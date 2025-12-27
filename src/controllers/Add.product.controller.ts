import { Request, Response } from "express";
import { PostValidator } from "../validators/Post.validator";
import prisma from "../prisma/client";

export const AddPost = async (req: Request, res: Response) => {
  const { value, error } = PostValidator.validate(req.body);
  if (error) {
    return res.status(403).json({ errors: error.details });
  }

  const { name, description, price, stock, category } = value;

  // Get userId from request (set by auth middleware)
  const userId = req.user?.id;
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

//so this is the change i have made and dejen please accept it 