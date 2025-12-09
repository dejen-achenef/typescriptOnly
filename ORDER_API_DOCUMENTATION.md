# Order Management API - Complete Documentation

## Table of Contents
1. [Create New Order Endpoint](#create-new-order-endpoint)
2. [View Order History Endpoint](#view-order-history-endpoint)
3. [Understanding the Code](#understanding-the-code)

---

## Create New Order Endpoint

### Overview
This endpoint allows authenticated users to place orders for products. When a user wants to buy multiple products, they send a request with a list of products and quantities. The system checks if there's enough stock, calculates the total price, creates the order, and updates the product stock - all in one secure transaction.

### Endpoint Details
- **URL:** `POST /orders`
- **Authentication:** Required (JWT token in cookies)
- **Authorization:** Only users with "User" role can place orders

### Request Format

#### Headers
```
Cookie: AccessToken=<your-jwt-token>
Content-Type: application/json
```

#### Request Body
```json
{
  "items": [
    {
      "productId": "550e8400-e29b-41d4-a716-446655440000",
      "quantity": 2
    },
    {
      "productId": "660e8400-e29b-41d4-a716-446655440001",
      "quantity": 1
    }
  ]
}
```

**Field Explanations:**
- `items`: An array of products the user wants to order
- `productId`: The unique identifier (UUID) of the product
- `quantity`: How many units of that product the user wants

### Response Formats

#### Success Response (201 Created)
```json
{
  "success": true,
  "message": "Order created successfully",
  "order": {
    "order_id": "770e8400-e29b-41d4-a716-446655440002",
    "status": "pending",
    "total_price": 150.00,
    "products": [
      {
        "productId": "550e8400-e29b-41d4-a716-446655440000",
        "name": "Product A",
        "price": 50.00,
        "quantity": 2
      },
      {
        "productId": "660e8400-e29b-41d4-a716-446655440001",
        "name": "Product B",
        "price": 50.00,
        "quantity": 1
      }
    ]
  }
}
```

#### Error Responses

**400 Bad Request - Validation Error**
```json
{
  "errors": [
    {
      "message": "\"productId\" must be a valid GUID",
      "path": ["items", 0, "productId"]
    }
  ]
}
```

**400 Bad Request - Insufficient Stock**
```json
{
  "success": false,
  "error": "Insufficient stock for Product A. Available: 1, Requested: 2"
}
```

**401 Unauthorized - Not Authenticated**
```json
{
  "error": "User not authenticated"
}
```

**403 Forbidden - Wrong Role**
```json
{
  "error": "Access denied. Only users with 'User' role can place orders."
}
```

**500 Internal Server Error**
```json
{
  "success": false,
  "error": "Failed to create order",
  "message": "Database connection error"
}
```

---

## View Order History Endpoint

### Overview
This endpoint allows authenticated users to view all their previous orders. Users can see their complete purchase history, including order status and total prices. Each user can only see their own orders - never another user's orders.

### Endpoint Details
- **URL:** `GET /orders`
- **Authentication:** Required (JWT token in cookies)
- **Authorization:** Any authenticated user can view their own orders

### Request Format

#### Headers
```
Cookie: AccessToken=<your-jwt-token>
```

#### Request Body
None required (GET request)

### Response Formats

#### Success Response (200 OK) - With Orders
```json
{
  "success": true,
  "orders": [
    {
      "order_id": "770e8400-e29b-41d4-a716-446655440002",
      "status": "pending",
      "total_price": 150.00
    },
    {
      "order_id": "880e8400-e29b-41d4-a716-446655440003",
      "status": "completed",
      "total_price": 75.50
    }
  ],
  "count": 2
}
```

#### Success Response (200 OK) - No Orders
```json
{
  "success": true,
  "orders": [],
  "count": 0
}
```

#### Error Responses

**401 Unauthorized - Not Authenticated**
```json
{
  "error": "Unauthorized - User not authenticated"
}
```

**500 Internal Server Error**
```json
{
  "success": false,
  "error": "Failed to fetch order history",
  "message": "Database connection error"
}
```

---

## Understanding the Code

### Create New Order - Line by Line Explanation

#### File: `src/controllers/create.new.order.ts`

```typescript
import { Request, Response } from "express";
import prisma from "../prisma/client";
import { OrderValidator } from "../validators/Order.validator";
```

**What this does:**
- Imports necessary tools:
  - `Request` and `Response`: Types for handling HTTP requests and responses
  - `prisma`: Database connection tool to interact with the database
  - `OrderValidator`: Validation tool to check if the request data is correct

```typescript
export const createNewOrder = async (req: Request, res: Response) => {
```

**What this does:**
- Creates a function called `createNewOrder` that handles order creation
- `async`: This function can wait for database operations to complete
- `req`: Contains the incoming request data (what the user sent)
- `res`: Used to send a response back to the user

```typescript
  // Validate request body
  const { value, error } = OrderValidator.validate(req.body);
  if (error) {
    return res.status(400).json({ errors: error.details });
  }
```

**What this does:**
- Checks if the request data is valid (correct format, required fields present)
- `OrderValidator.validate()`: Examines the request body against rules
- If validation fails:
  - Returns HTTP status 400 (Bad Request)
  - Sends back error details so the user knows what's wrong
  - Stops execution (doesn't continue to create the order)

**Example of validation failure:**
- User sends `quantity: -5` → Error: "quantity must be at least 1"
- User sends `productId: "not-a-uuid"` → Error: "productId must be a valid UUID"

```typescript
  const { items } = value;
  const userId = (req as any).user?.id;

  if (!userId) {
    return res.status(401).json({ error: "User not authenticated" });
  }
```

**What this does:**
- Extracts the `items` array from the validated request data
- Gets the user's ID from the authentication token (set by auth middleware)
- If no user ID is found:
  - Returns HTTP status 401 (Unauthorized)
  - Sends error message
  - Stops execution

**Why this matters:**
- Ensures only logged-in users can place orders
- Prevents anonymous users from creating orders

```typescript
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
```

**What this does:**
- Looks up the user in the database using their ID
- `await`: Waits for the database query to complete
- `prisma.user.findUnique()`: Searches for one specific user by ID
- Checks if user exists; if not, returns 401 error
- Checks if user has "User" role (not "Admin" or other roles)
- If role is wrong, returns 403 (Forbidden) error

**Why this matters:**
- Prevents admins from placing orders (they have different permissions)
- Ensures only regular users can use this endpoint

```typescript
  try {
    // Use transaction to ensure atomicity
    const result = await prisma.$transaction(async (tx) => {
```

**What this does:**
- Starts a database transaction
- `$transaction`: Groups multiple database operations together
- `async (tx) =>`: Creates a function that uses the transaction context
- If ANY operation fails, ALL changes are rolled back (nothing is saved)

**Why transactions matter:**
- **Example scenario without transaction:**
  1. Check stock: Product A has 5 units ✓
  2. Create order ✓
  3. Update stock: Product A now has 3 units ✓
  4. **ERROR:** Database crashes
  5. Order exists but stock wasn't updated → Data inconsistency!

- **With transaction:**
  1. Check stock: Product A has 5 units ✓
  2. Create order ✓
  3. Update stock: Product A now has 3 units ✓
  4. **ERROR:** Database crashes
  5. **Transaction rolls back** → Order is deleted, stock stays at 5 → Data consistent!

```typescript
      // Step 1: Fetch all products and validate stock
      const productIds = items.map((item: any) => item.productId);
      const products = await tx.product.findMany({
        where: {
          id: { in: productIds },
        },
      });
```

**What this does:**
- **Step 1a:** Extracts all product IDs from the request
  - `items.map()`: Goes through each item and gets just the productId
  - Example: `[{productId: "abc", quantity: 2}, {productId: "def", quantity: 1}]` → `["abc", "def"]`
  
- **Step 1b:** Fetches all products from the database in one query
  - `tx.product.findMany()`: Gets multiple products
  - `where: { id: { in: productIds } }`: Finds products whose IDs are in our list
  - `await`: Waits for database to return results

**Why fetch all at once:**
- More efficient than querying one product at a time
- Reduces database load and improves speed

```typescript
      // Check if all products exist
      if (products.length !== productIds.length) {
        const foundIds = new Set(products.map((p) => p.id));
        const missingIds = productIds.filter((id: string) => !foundIds.has(id));
        throw new Error(`Products not found: ${missingIds.join(", ")}`);
      }
```

**What this does:**
- Compares the number of products found vs. products requested
- If counts don't match, some products don't exist
- Creates a Set (fast lookup structure) of found product IDs
- Finds which product IDs were requested but not found
- Throws an error with the missing product IDs

**Example:**
- User requests: `["abc", "def", "ghi"]`
- Database has: `["abc", "def"]` (missing "ghi")
- Error: "Products not found: ghi"

```typescript
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
```

**What this does:**
- **Step 2a:** Initializes variables
  - `totalPrice = 0`: Starting point for calculating total
  - `stockChecks = []`: Array to store products that passed stock validation

- **Step 2b:** Loops through each item in the order
  - `for (const item of items)`: Goes through each product the user wants

- **Step 2c:** Finds the product in our fetched products list
  - `products.find()`: Searches for product with matching ID

- **Step 2d:** Checks if product exists (double-check)
  - If not found, throws error

- **Step 2e:** Validates stock availability
  - Compares `product.stock` (available) vs `item.quantity` (requested)
  - If stock is less than requested, throws detailed error
  - Example: "Insufficient stock for Laptop. Available: 2, Requested: 5"

- **Step 2f:** Calculates total price
  - Multiplies product price by quantity
  - Adds to running total
  - Example: Product A ($50 × 2) + Product B ($30 × 1) = $130

- **Step 2g:** Stores validated product for later use
  - Adds product and quantity to `stockChecks` array

**Why calculate price on server:**
- **Security:** Client could send fake prices
- **Accuracy:** Prices might change; we use current database prices
- **Trust:** Server is the source of truth

```typescript
      // Step 3: Create order
      const order = await tx.order.create({
        data: {
          userId,
          description: "New Order",
          totalPrice,
          status: "pending",
        },
      });
```

**What this does:**
- Creates a new order record in the database
- `tx.order.create()`: Inserts a new row in the orders table
- **Data being saved:**
  - `userId`: Links order to the user who placed it
  - `description`: Brief description ("New Order")
  - `totalPrice`: The calculated total (from Step 2)
  - `status`: Set to "pending" (order is new, not yet processed)
- `await`: Waits for database to save the order
- Returns the created order (with generated ID)

**Database record created:**
```
Order {
  id: "770e8400-e29b-41d4-a716-446655440002" (auto-generated)
  userId: "user-123"
  description: "New Order"
  totalPrice: 150.00
  status: "pending"
}
```

```typescript
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
```

**What this does:**
- **Step 4a:** `Promise.all()`: Runs multiple operations in parallel (faster than one-by-one)
- **Step 4b:** `stockChecks.map()`: Goes through each validated product

- **For each product:**
  - **Creates order item:**
    - `tx.orderItem.create()`: Saves a record linking the order to a product
    - Links: Which order, which product, how many
    - Example: Order #123, Product A, Quantity 2
  
  - **Updates product stock:**
    - `tx.product.update()`: Modifies the product's stock
    - `decrement`: Subtracts the ordered quantity from available stock
    - Example: Product A had 10 units, ordered 2 → now has 8 units

**Why update stock:**
- Prevents overselling (selling more than available)
- Keeps inventory accurate
- Other users see updated stock immediately

**Example:**
- Product A: Stock 10 → Order 2 → Stock 8
- Product B: Stock 5 → Order 1 → Stock 4

```typescript
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
```

**What this does:**
- Fetches the complete order with all related data
- `tx.order.findUnique()`: Gets the order by its ID
- `include`: Tells Prisma to also fetch related data
  - `orderItems`: All items in this order
  - `product`: For each item, get product details
  - `select`: Only get specific product fields (id, name, price, description)
- Returns the complete order object

**Why fetch again:**
- The order now has all items attached
- We can return complete information to the user
- Includes product names, prices, etc. for display

**Data structure returned:**
```json
{
  "id": "order-123",
  "userId": "user-456",
  "totalPrice": 150.00,
  "status": "pending",
  "orderItems": [
    {
      "id": "item-1",
      "quantity": 2,
      "product": {
        "id": "product-abc",
        "name": "Laptop",
        "price": 50.00,
        "description": "High-performance laptop"
      }
    }
  ]
}
```

```typescript
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
```

**What this does:**
- Sends success response to the user
- `res.status(201)`: HTTP status "Created" (new resource created)
- `res.json()`: Sends JSON response
- **Response structure:**
  - `success: true`: Indicates operation succeeded
  - `message`: Human-readable success message
  - `order`: Formatted order data
    - `order_id`: The order's unique identifier
    - `status`: Current order status
    - `total_price`: Total cost
    - `products`: Array of products in the order
      - `result!.orderItems.map()`: Transforms order items into simpler format
      - Extracts: productId, name, price, quantity

**Why format the response:**
- Hides internal database structure
- Provides only necessary information
- Makes it easier for frontend to display

```typescript
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
```

**What this does:**
- Catches any errors that occurred during order creation
- **Error handling logic:**
  - Checks if error is about stock or missing products
  - If yes: Returns 400 (Bad Request) - user's fault (requested unavailable items)
  - If no: Returns 500 (Internal Server Error) - server's fault (database issue, etc.)
- `console.error()`: Logs error for developers to debug
- Sends error response to user

**Error scenarios:**
1. **Stock error:** User requests 10 units, only 5 available → 400 error
2. **Database error:** Database connection lost → 500 error
3. **Transaction rollback:** If any step fails, all changes are undone automatically

---

### View Order History - Line by Line Explanation

#### File: `src/controllers/order.history.ts`

```typescript
import { Request, Response } from "express";
import prisma from "../prisma/client";

export const getOrderHistory = async (req: Request, res: Response) => {
```

**What this does:**
- Imports necessary tools (same as create order)
- Creates function to handle order history requests
- `async`: Can wait for database operations

```typescript
  const userId = (req as any).user?.id;

  if (!userId) {
    return res.status(401).json({ error: "Unauthorized - User not authenticated" });
  }
```

**What this does:**
- Gets user ID from authentication token
- Checks if user is authenticated
- If not authenticated: Returns 401 error and stops

**Security:**
- Prevents unauthenticated users from accessing order history
- Ensures we know which user is making the request

```typescript
  try {
    // Fetch all orders for the authenticated user
    const orders = await prisma.order.findMany({
      where: {
        userId: userId,
      },
```

**What this does:**
- Starts error handling block
- Fetches orders from database
- `prisma.order.findMany()`: Gets multiple orders
- `where: { userId: userId }`: **CRITICAL SECURITY** - Only gets orders for this specific user

**Why this is important:**
- User A can NEVER see User B's orders
- Database filters orders by userId automatically
- Even if someone tries to hack, they can't access other users' data

```typescript
      include: {
        orderItems: {
          include: {
            product: {
              select: {
                id: true,
                name: true,
                price: true,
              },
            },
          },
        },
      },
```

**What this does:**
- Tells Prisma to include related data
- `orderItems`: Gets all items in each order
- `product`: For each item, gets product information
- `select`: Only gets specific product fields (id, name, price)

**Why include related data:**
- User wants to see what products they ordered
- Not just order IDs, but product names and prices
- Makes the response more useful

```typescript
      orderBy: {
        // Order by most recent first (if createdAt exists) or by id
        id: "desc",
      },
    });
```

**What this does:**
- Sorts orders by ID in descending order
- `id: "desc"`: Newest orders first (higher IDs = newer)
- If `createdAt` field existed, would use that instead

**Why sort:**
- Users expect to see newest orders first
- Makes order history more user-friendly

```typescript
    // Format the response
    const formattedOrders = orders.map((order) => ({
      order_id: order.id,
      status: order.status,
      total_price: order.totalPrice,
      // Note: createdAt is not in the schema. To add it, update prisma/schema.prisma:
      // createdAt DateTime @default(now())
      // Then run: npx prisma migrate dev
    }));
```

**What this does:**
- Transforms database results into simpler format
- `orders.map()`: Goes through each order and reformats it
- **For each order:**
  - `order_id`: The order's unique identifier
  - `status`: Current status (pending, completed, etc.)
  - `total_price`: Total cost of the order
- Note about `createdAt`: Explains how to add timestamp field if needed

**Why format:**
- Hides complex database structure
- Provides clean, simple data for frontend
- Consistent with API response format

```typescript
    return res.status(200).json({
      success: true,
      orders: formattedOrders,
      count: formattedOrders.length,
    });
```

**What this does:**
- Sends success response
- `res.status(200)`: HTTP status "OK" (request succeeded)
- **Response includes:**
  - `success: true`: Operation succeeded
  - `orders`: Array of formatted orders
  - `count`: Number of orders (convenience for frontend)

**Example responses:**
- **With orders:** Returns array with order objects
- **No orders:** Returns empty array `[]` with count 0

```typescript
  } catch (error: any) {
    console.error("Error fetching order history:", error);
    return res.status(500).json({
      success: false,
      error: "Failed to fetch order history",
      message: error.message,
    });
  }
};
```

**What this does:**
- Catches any errors during order fetching
- Logs error for developers
- Returns 500 error to user
- Includes error message for debugging

**Error scenarios:**
- Database connection lost
- Invalid user ID format
- Database query failure

---

## Security Considerations

### Authentication
- Both endpoints require JWT token in cookies
- Token is verified by `authMiddleware` before reaching controller
- Invalid or missing token → 401 Unauthorized

### Authorization
- **Create Order:** Only users with "User" role can place orders
- **View History:** Any authenticated user can view their own orders

### Data Isolation
- Order history filters by `userId` from JWT
- Users can NEVER see other users' orders
- Database query enforces user isolation

### Input Validation
- Request data is validated before processing
- Invalid UUIDs, negative quantities, etc. are rejected
- Prevents malicious or malformed requests

### Transaction Safety
- Order creation uses database transactions
- All-or-nothing: Either everything succeeds or nothing is saved
- Prevents partial orders or inconsistent data

---

## Database Schema Reference

### Order Model
```prisma
model Order {
  id          String      @id @default(uuid())
  userId      String
  description String
  totalPrice  Float
  status      String
  orderItems  OrderItem[]
}
```

### OrderItem Model
```prisma
model OrderItem {
  id        String   @id @default(uuid())
  orderId   String
  productId String
  quantity  Int
  order     Order    @relation(...)
  product   Product  @relation(...)
}
```

### Product Model (relevant fields)
```prisma
model Product {
  id          String    @id @default(uuid())
  name        String
  price       Float
  stock       Int
  orderItems  OrderItem[]
}
```

---

## Testing Examples

### Test Create Order (using curl)

```bash
curl -X POST http://localhost:3000/orders \
  -H "Content-Type: application/json" \
  -H "Cookie: AccessToken=your-jwt-token-here" \
  -d '{
    "items": [
      {
        "productId": "550e8400-e29b-41d4-a716-446655440000",
        "quantity": 2
      }
    ]
  }'
```

### Test View Order History (using curl)

```bash
curl -X GET http://localhost:3000/orders \
  -H "Cookie: AccessToken=your-jwt-token-here"
```

### Test with Postman
1. Set method to POST (create) or GET (history)
2. Enter URL: `http://localhost:3000/orders`
3. In Headers tab, add: `Cookie: AccessToken=your-token`
4. For POST, in Body tab, select "raw" and "JSON", paste request body
5. Click Send

---

## Common Issues and Solutions

### Issue: "User not authenticated"
**Cause:** Missing or invalid JWT token
**Solution:** 
1. Login first to get a token
2. Include token in Cookie header
3. Ensure token hasn't expired

### Issue: "Insufficient stock"
**Cause:** Requested quantity exceeds available stock
**Solution:** 
1. Check product stock before ordering
2. Reduce quantity
3. Wait for restock

### Issue: "Products not found"
**Cause:** Invalid product ID or product was deleted
**Solution:** 
1. Verify product IDs are correct UUIDs
2. Check if products still exist in database

### Issue: "Access denied. Only users with 'User' role can place orders"
**Cause:** User has "Admin" or other role, not "User"
**Solution:** 
1. Use an account with "User" role
2. Or modify role in database if needed

---

## Summary

### Create Order Flow
1. User sends POST request with products and quantities
2. System validates request data
3. System verifies user authentication and role
4. System checks product existence and stock
5. System calculates total price from database
6. System creates order in transaction
7. System creates order items
8. System updates product stock
9. System returns order details

### View History Flow
1. User sends GET request
2. System verifies user authentication
3. System fetches orders for that user only
4. System formats order data
5. System returns order list (or empty array)

Both endpoints are secure, validated, and handle errors gracefully. The transaction system ensures data consistency, and user isolation prevents unauthorized access to other users' orders.

