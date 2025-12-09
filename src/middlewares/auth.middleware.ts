
import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";

export const authMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const token = req.cookies?.AccessToken;
  
  if (!token) {
    return res.status(401).json({ error: "Unauthorized - No token provided" });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || "supersecretkey") as { id: string; email: string };
    (req as any).user = decoded;
    next();
  } catch (error: any) {
    console.error("JWT verification error:", error.message);
    return res.status(401).json({ error: "Unauthorized - Invalid token" });
  }
};