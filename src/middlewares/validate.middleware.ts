import { Request, Response, NextFunction } from "express";

export const roleChecker = (req: Request, res: Response, next: NextFunction) => {
  try {
    const role = req.user?.role;

    if (!role) {
      return res.status(401).json({ error: "Unauthorized - User role not found" });
    }

    if (role === "admin") {
      return next();
    }

    return res.status(403).json({ 
      error: "Forbidden - You are not authorized to access this resource" 
    });
  } catch (error: any) {
    console.error("Role check error:", error.message);
    return res.status(401).json({ error: "Unauthorized - Invalid token" });
  }
};
