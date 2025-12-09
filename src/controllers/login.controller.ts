import { Request, Response } from "express";
import prisma from "../prisma/client";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { userLoginvalidator } from "../validators/user.validator"; // Joi schema

export const Login = async (req: Request, res: Response) => {
  // Validate input
  const { value, error } = userLoginvalidator.validate(req.body);
  if (error) {
    return res.status(400).json({ errors: error.details });
  }

  const { email, username, password } = value;

  // Find user by email or username
  const existingUser = await prisma.user.findFirst({
    where: { OR: [{ email }, { username }] },
  });

  if (!existingUser) {
    return res.status(404).json({ message: "User not found" });
  }

  // Compare password
  const passwordCompare = await bcrypt.compare(password, existingUser.password);
  if (!passwordCompare) {
    return res.status(401).json({
      success: false,
      message: "Invalid email or password",
    });
  }

  // Generate JWT
  try {
    const token = jwt.sign(
      { id: existingUser.id, email: existingUser.email },
      process.env.JWT_SECRET || "supersecretkey",
      { expiresIn: "1h" }
    );

    res.cookie("AccessToken", token, {
      httpOnly: true,
      secure: false, // set true in production with HTTPS
      maxAge: 1000 * 60 * 60, // 1 hour
    });

    return res.status(200).json({
      message: "User logged in successfully",
      success: true,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Unexpected error happened",
    });
  }
};
