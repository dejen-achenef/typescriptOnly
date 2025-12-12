import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";

const JWT_SECRET = process.env.JWT_SECRET || "supersecretkey";

export const authMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const token = req.cookies?.AccessToken;

  if (!token) {
    return res.status(401).json({ error: "Unauthorized - No token provided" });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET) as { id: string; email: string; role?: string };
    req.user = decoded;
    next();
  } catch (error: any) {
    console.error("JWT verification error:", error.message);
    return res.status(401).json({ error: "Unauthorized - Invalid token" });
  }
};