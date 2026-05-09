package handlers

import (
	"log/slog"

	"github.com/gofiber/fiber/v2"
	"github.com/shopverse/backend/internal/database"
	"github.com/shopverse/backend/internal/models"
	"github.com/shopverse/backend/internal/observability"
)

func GetCart(c *fiber.Ctx) error {
	db := database.DB.WithContext(observability.RequestContext(c))
	userID := c.Locals("userID").(uint)

	var items []models.CartItem
	if result := db.Preload("Product").Where("user_id = ?", userID).Find(&items); result.Error != nil {
		slog.Error("cart_fetch_failed", slog.String("error", result.Error.Error()))
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to fetch cart",
		})
	}

	return c.JSON(items)
}

func AddToCart(c *fiber.Ctx) error {
	db := database.DB.WithContext(observability.RequestContext(c))
	userID := c.Locals("userID").(uint)

	var req models.AddToCartRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	if req.ProductID == 0 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Product ID is required",
		})
	}

	if req.Quantity <= 0 {
		req.Quantity = 1
	}

	var product models.Product
	if result := db.First(&product, req.ProductID); result.Error != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"error": "Product not found",
		})
	}

	var existingItem models.CartItem
	result := db.Where("user_id = ? AND product_id = ?", userID, req.ProductID).First(&existingItem)
	if result.Error == nil {
		existingItem.Quantity += req.Quantity
		db.Save(&existingItem)
		db.Preload("Product").First(&existingItem, existingItem.ID)
		return c.JSON(existingItem)
	}

	item := models.CartItem{
		UserID:    userID,
		ProductID: req.ProductID,
		Quantity:  req.Quantity,
	}

	if result := db.Create(&item); result.Error != nil {
		slog.Error("cart_add_failed", slog.String("error", result.Error.Error()))
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to add item to cart",
		})
	}

	db.Preload("Product").First(&item, item.ID)
	return c.Status(fiber.StatusCreated).JSON(item)
}

func UpdateCartItem(c *fiber.Ctx) error {
	db := database.DB.WithContext(observability.RequestContext(c))
	userID := c.Locals("userID").(uint)
	id := c.Params("id")

	var req models.UpdateCartRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	if req.Quantity <= 0 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Quantity must be greater than 0",
		})
	}

	var item models.CartItem
	if result := db.Where("id = ? AND user_id = ?", id, userID).First(&item); result.Error != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"error": "Cart item not found",
		})
	}

	item.Quantity = req.Quantity
	db.Save(&item)
	db.Preload("Product").First(&item, item.ID)

	return c.JSON(item)
}

func RemoveCartItem(c *fiber.Ctx) error {
	db := database.DB.WithContext(observability.RequestContext(c))
	userID := c.Locals("userID").(uint)
	id := c.Params("id")

	result := db.Where("id = ? AND user_id = ?", id, userID).Delete(&models.CartItem{})
	if result.RowsAffected == 0 {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"error": "Cart item not found",
		})
	}

	return c.JSON(fiber.Map{"message": "Item removed from cart"})
}
