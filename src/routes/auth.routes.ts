import { Router } from "express";
import { Register } from "../controllers/signup.controller";
import { Login } from "../controllers/login.controller";
import { AddPost } from "../controllers/Add.product.controller";
import { authMiddleware } from "../middlewares/auth.middleware";
import { roleChecker } from "../middlewares/validate.middleware";
import { updatePost } from "../controllers/update.controller";
import { getProducts } from "../controllers/get.Products.controller";
import { searchProducts } from "../controllers/search.products.controller";
import { getProductDetail } from "../controllers/get.product.detail";
import { deleteProduct } from "../controllers/delete.product";
import { createNewOrder } from "../controllers/create.new.order";
import { getOrderHistory } from "../controllers/order.history";

const router = Router();

// Test route
router.get("/test", (req, res) => {
  res.json({ message: "Routes are working" });
});

router.post("/auth/register", Register);
router.post("/auth/login", Login);
router.post("/auth/post", authMiddleware,roleChecker, AddPost);
router.post("/auth/update/:id", authMiddleware,roleChecker, updatePost);
router.get("/auth/products", getProducts);
router.get("/auth/search", searchProducts);
router.get("/auth/product/:id", getProductDetail);
router.delete("/auth/delete/:id", authMiddleware,roleChecker, deleteProduct);
router.post("/orders", authMiddleware, createNewOrder);
router.get("/orders", authMiddleware, getOrderHistory);
export default router;
