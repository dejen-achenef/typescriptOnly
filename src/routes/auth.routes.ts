import { Router } from "express";
import { Register } from "../controllers/signup.controller";
import { Login } from "../controllers/login.controller";
import { AddPost } from "../controllers/Add.product.controller";
import { authMiddleware } from "../middlewares/auth.middleware";
import { roleChecker } from "../middlewares/validate.middleware";

const router = Router();

// Test route
router.get("/test", (req, res) => {
  res.json({ message: "Routes are working" });
});

router.post("/auth/register", Register);
router.post("/auth/login", Login);
router.post("/auth/post", authMiddleware,roleChecker, AddPost);

export default router;
