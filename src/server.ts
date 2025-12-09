import "dotenv/config";
import express from "express";
import cookieParser from "cookie-parser";
import { Pool } from "pg";
import { PrismaPg } from "@prisma/adapter-pg";
import router from "./routes/auth.routes";

const app = express();
app.use(express.json());
app.use(cookieParser());

// Load DATABASE_URL from environment
const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
  throw new Error("DATABASE_URL environment variable is not set");
}

// Create Pool instance
const pool = new Pool({ connectionString });

// Create PrismaPg adapter
const adapter = new PrismaPg(pool);

app.use("/", router);

// Catch-all for debugging
app.use((req, res) => {
  console.log(`404 - Method: ${req.method}, Path: ${req.path}`);
  res.status(404).json({ error: `Cannot ${req.method} ${req.path}` });
});

app.listen(3000, () => {
  console.log("server is running on port 3000");
  console.log("Available routes:");
  console.log("  POST /auth/register");
  console.log("  POST /auth/login");
  console.log("  POST /auth/post");
  console.log("  GET /test");
});
