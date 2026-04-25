#include <iostream>
#include <vector>
#include <string>
#include <algorithm>

// structure for a warehouse location with its stock
struct Location {
    int location_id;
    std::string location_code;
    std::string zone;
    int quantity;
};

// structure for a product
struct Product {
    int product_id;
    std::string product_name;
    std::vector<Location> locations;
};

// sort locations from fullest to emptiest
bool compareByQuantity(const Location& a, const Location& b) {
    return a.quantity > b.quantity;
}

// suggests which locations to pick stock from first
void allocateStock(Product& product, int needed) {
    std::cout << "\n--- Stock Allocation for: " << product.product_name << " ---" << std::endl;
    std::cout << "Required quantity: " << needed << std::endl;

    std::sort(product.locations.begin(), product.locations.end(), compareByQuantity);

    int remaining = needed;

    for (auto& loc : product.locations) {
        if (remaining <= 0) break;
        if (loc.quantity <= 0) continue;

        int take = std::min(remaining, loc.quantity);

        std::cout << "  Location " << loc.location_code
                  << " (zone: " << loc.zone << ")"
                  << " -> take " << take
                  << " (available: " << loc.quantity << ")" << std::endl;

        remaining -= take;
    }

    if (remaining > 0) {
        std::cout << "  WARNING: Not enough stock! Missing " << remaining << " units." << std::endl;
    } else {
        std::cout << "  OK: Order can be fulfilled." << std::endl;
    }
}

int main() {
    std::cout << "=== STOCK ALLOCATION HELPER ===" << std::endl;
    std::cout << "Suggests which location to pick stock from first." << std::endl;

    // test data - matches database sample data
    // COLD products
    Product milk;
    milk.product_id = 1;
    milk.product_name = "Milk";
    milk.locations.push_back({1, "FR-A1", "COLD_ZONE_A", 50});

    Product yogurt;
    yogurt.product_id = 2;
    yogurt.product_name = "Yogurt";
    yogurt.locations.push_back({1, "FR-A1", "COLD_ZONE_A", 30});

    Product cheese;
    cheese.product_id = 3;
    cheese.product_name = "Cheese";
    cheese.locations.push_back({2, "FR-A2", "COLD_ZONE_A", 40});

    // DRY products
    Product rice;
    rice.product_id = 4;
    rice.product_name = "Rice";
    rice.locations.push_back({4, "DR-A1", "DRY_ZONE_A", 80});

    Product pasta;
    pasta.product_id = 5;
    pasta.product_name = "Pasta";
    pasta.locations.push_back({5, "DR-A2", "DRY_ZONE_A", 60});

    Product cereal;
    cereal.product_id = 6;
    cereal.product_name = "Cereal";
    cereal.locations.push_back({6, "DR-B1", "DRY_ZONE_B", 70});

    // test scenarios
    std::cout << "\n-- Scenario 1: Normal order --" << std::endl;
    allocateStock(milk, 10);
    allocateStock(yogurt, 5);

    std::cout << "\n-- Scenario 2: Dry products order --" << std::endl;
    allocateStock(rice, 20);
    allocateStock(pasta, 15);

    std::cout << "\n-- Scenario 3: Insufficient stock --" << std::endl;
    allocateStock(milk, 9999);
    allocateStock(cereal, 9999);

    std::cout << "\n=== DONE ===" << std::endl;

    return 0;
}
