#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <string>
using namespace std;

struct Location {
    int locationId;
    string locationCode;
    char isRefrigerated;
    int capacity;
    int usedCapacity;
    string productIds;
};

bool locationContainsProduct(const string& productIds, int productId) {
    if (productIds == "NONE" || productIds.empty()) {
        return false;
    }

    stringstream ss(productIds);
    string token;

    while (getline(ss, token, '|')) {
        if (!token.empty() && stoi(token) == productId) {
            return true;
        }
    }

    return false;
}

string addProductToList(const string& productIds, int productId) {
    if (locationContainsProduct(productIds, productId)) {
        return productIds;
    }

    if (productIds == "NONE" || productIds.empty()) {
        return to_string(productId);
    }

    return productIds + "|" + to_string(productId);
}

vector<Location> readLocationsFromCsv(const string& filename) {
    vector<Location> locations;
    ifstream file(filename);

    if (!file.is_open()) {
        cerr << "ERROR: Could not open input file: " << filename << endl;
        return locations;
    }

    string line;
    getline(file, line); // skip header

    while (getline(file, line)) {
        if (line.empty()) continue;

        stringstream ss(line);
        string field;
        Location loc;

        getline(ss, field, ',');
        loc.locationId = stoi(field);

        getline(ss, loc.locationCode, ',');

        getline(ss, field, ',');
        loc.isRefrigerated = field[0];

        getline(ss, field, ',');
        loc.capacity = stoi(field);

        getline(ss, field, ',');
        loc.usedCapacity = stoi(field);

        getline(ss, loc.productIds, ',');

        locations.push_back(loc);
    }

    return locations;
}

bool writeLocationsToCsv(const string& filename, const vector<Location>& locations) {
    ofstream file(filename);

    if (!file.is_open()) {
        cerr << "ERROR: Could not write to file: " << filename << endl;
        return false;
    }

    file << "location_id,location_code,is_refrigerated,capacity,used_capacity,product_ids\n";

    for (const auto& loc : locations) {
        file << loc.locationId << ","
             << loc.locationCode << ","
             << loc.isRefrigerated << ","
             << loc.capacity << ","
             << loc.usedCapacity << ","
             << loc.productIds << "\n";
    }

    return true;
}

int main(int argc, char* argv[]) {
    if (argc != 7) {
        cerr << "Usage: ./location_allocator <product_id> <requires_refrigeration Y/N> <quantity> <locations_csv> <update_state Y/N> <prefer_same_product Y/N>" << endl;
        return 1;
    }

    int incomingProductId = stoi(argv[1]);
    char requiredRefrigeration = argv[2][0];
    int incomingQuantity = stoi(argv[3]);
    string csvFile = argv[4];
    char updateState = argv[5][0];
    char preferSameProduct = argv[6][0];

    if (requiredRefrigeration != 'Y' && requiredRefrigeration != 'N') {
        cerr << "ERROR: requires_refrigeration must be Y or N." << endl;
        return 1;
    }

    if (incomingQuantity <= 0) {
        cerr << "ERROR: quantity must be greater than 0." << endl;
        return 1;
    }

    vector<Location> locations = readLocationsFromCsv(csvFile);

    if (locations.empty()) {
        cerr << "ERROR: No locations available for evaluation." << endl;
        return 1;
    }

    int selectedIndex = -1;
    int bestFreeCapacity = 1000000000;
    string reason;

    // Rule 1: Prefer same-product location if enabled
    if (preferSameProduct == 'Y') {
        for (size_t i = 0; i < locations.size(); i++) {
            int freeCapacity = locations[i].capacity - locations[i].usedCapacity;

            if (
                locations[i].isRefrigerated == requiredRefrigeration &&
                locationContainsProduct(locations[i].productIds, incomingProductId) &&
                freeCapacity >= incomingQuantity &&
                freeCapacity < bestFreeCapacity
            ) {
                selectedIndex = static_cast<int>(i);
                bestFreeCapacity = freeCapacity;
                reason = "Selected best-fit same-product location";
            }
        }
    }

    // Rule 2: Best-fit compatible location
    if (selectedIndex == -1) {
        bestFreeCapacity = 1000000000;

        for (size_t i = 0; i < locations.size(); i++) {
            int freeCapacity = locations[i].capacity - locations[i].usedCapacity;

            if (
                locations[i].isRefrigerated == requiredRefrigeration &&
                freeCapacity >= incomingQuantity &&
                freeCapacity < bestFreeCapacity
            ) {
                selectedIndex = static_cast<int>(i);
                bestFreeCapacity = freeCapacity;
                reason = "Selected best-fit compatible location";
            }
        }
    }

    if (selectedIndex == -1) {
        cerr << "ERROR: No suitable location found." << endl;
        return 2;
    }

    Location& selected = locations[selectedIndex];

    cout << selected.locationId << ","
              << selected.locationCode << ","
              << reason;

    if (updateState == 'Y') {
        selected.usedCapacity += incomingQuantity;
        selected.productIds = addProductToList(selected.productIds, incomingProductId);

        if (!writeLocationsToCsv(csvFile, locations)) {
            return 1;
        }

        cout << ",CSV state updated";
    } else {
        cout << ",CSV state not updated";
    }

    cout << endl;

    return 0;
}