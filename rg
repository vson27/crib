#include <iostream>
#include <vector>
#include <chrono>
#include <random>
#include <cmath>
#include <iomanip>
using namespace std;
using namespace std::chrono;

/*---------------------------------------------------------------
 STEP 1: Generate True Random Bits using System Timing Jitter
 ----------------------------------------------------------------
  - We measure the time taken by a small loop.
  - Extract the Least Significant Bit (LSB) of the time difference.
  - Collect these bits into a vector as our raw TRNG bitstream.
----------------------------------------------------------------*/
vector<int> generateTRNGBits(int num_bits) 
{
    vector<int> bits;
    bits.reserve(num_bits * 2); // extra, since Von Neumann may discard some
    for (int i = 0; i < num_bits * 2; ++i) 
    {
        auto start = high_resolution_clock::now();

        // Do something small to create jitter
        for (volatile int j = 0; j < 1000; ++j);

        auto end = high_resolution_clock::now();
        auto diff = duration_cast<nanoseconds>(end - start).count();

        int lsb = diff & 1;  // take the least significant bit
        bits.push_back(lsb);
    }
    return bits;
}

/*---------------------------------------------------------------
 STEP 2: Von Neumann Extractor to Remove Bias
 ----------------------------------------------------------------
 - Pair bits: 01 -> 0, 10 -> 1, 00/11 discarded.
 - This reduces bias at the cost of bit length.
----------------------------------------------------------------*/
vector<int> vonNeumannExtract(const vector<int> &raw) {
    vector<int> processed;
    for (size_t i = 0; i + 1 < raw.size(); i += 2) {
        int b1 = raw[i];
        int b2 = raw[i + 1];
        if (b1 == 0 && b2 == 1) processed.push_back(0);
        else if (b1 == 1 && b2 == 0) processed.push_back(1);
        // 00 or 11 is ignored
    }
    return processed;
}

/*---------------------------------------------------------------
 STEP 3a: Shannon Entropy Calculation
 ----------------------------------------------------------------
 H = - (P0 * log2(P0) + P1 * log2(P1))
 P0 = # of 0s / total bits
 P1 = # of 1s / total bits
 Max entropy = 1 bit per bit (perfectly random)
----------------------------------------------------------------*/
double calculateEntropy(const vector<int>& bits) {
    if (bits.empty()) return 0.0;
    int zeros = 0;
    for (int b : bits) if (b == 0) zeros++;
    int ones = bits.size() - zeros;

    double p0 = (double)zeros / bits.size();
    double p1 = (double)ones / bits.size();

    double H = 0.0;
    if (p0 > 0) H -= p0 * log2(p0);
    if (p1 > 0) H -= p1 * log2(p1);
    return H;
}

/*---------------------------------------------------------------
 STEP 3b: Chi-Square Test
 ----------------------------------------------------------------
 χ² = ((O0 - E0)^2)/E0 + ((O1 - E1)^2)/E1
 O0, O1 = observed counts
 E0, E1 = expected counts (n/2 each)
----------------------------------------------------------------*/
double chiSquareTest(const vector<int>& bits) {
    if (bits.empty()) return 0.0;
    int zeros = 0;
    for (int b : bits) if (b == 0) zeros++;
    int ones = bits.size() - zeros;

    double expected = bits.size() / 2.0;
    double chi = ((zeros - expected) * (zeros - expected)) / expected
               + ((ones - expected) * (ones - expected)) / expected;
    return chi;
}

/*---------------------------------------------------------------
 STEP 4: Generate Pseudo Random Bits using mt19937
 ----------------------------------------------------------------
  - Generates a sequence of 0/1 bits using PRNG.
  - Used for comparison with TRNG.
----------------------------------------------------------------*/
vector<int> generatePRNGBits(int num_bits) {
    vector<int> bits;
    bits.reserve(num_bits);
    mt19937 gen(random_device{}());  // Mersenne Twister PRNG
    uniform_int_distribution<int> dist(0, 1);
    for (int i = 0; i < num_bits; ++i) {
        bits.push_back(dist(gen));
    }
    return bits;
}

/*---------------------------------------------------------------
 Helper Function: Count zeros and ones in bitstream
----------------------------------------------------------------*/
void printStats(const vector<int>& bits, const string& label) {
    int zeros = 0;
    for (int b : bits) if (b == 0) zeros++;
    int ones = bits.size() - zeros;

    double entropy = calculateEntropy(bits);
    double chi = chiSquareTest(bits);

    cout << "\n=== " << label << " ===" << endl;
    cout << "Total bits: " << bits.size() << endl;
    cout << "Zeros: " << zeros << "  Ones: " << ones << endl;
    cout << "P(0): " << fixed << setprecision(4) << (double)zeros/bits.size()
         << "  P(1): " << (double)ones/bits.size() << endl;
    cout << "Shannon Entropy: " << entropy << " bits" << endl;
    cout << "Chi-Square Value: " << chi << endl;
}

/*---------------------------------------------------------------
 MAIN FUNCTION
----------------------------------------------------------------*/
int main() {
    int NUM_BITS = 1024;  // required minimum

    cout << "=== TRNG vs PRNG Randomness ===" << endl;

    // 1. Generate Raw TRNG bits
    vector<int> raw_trng = generateTRNGBits(NUM_BITS);
    printStats(raw_trng, "Raw TRNG Bitstream");

    // 2. Apply Von Neumann Extractor
    vector<int> processed_trng = vonNeumannExtract(raw_trng);
    printStats(processed_trng, "Post-Processed TRNG (Von Neumann)");

    // 3. Generate PRNG bits
    vector<int> prng_bits = generatePRNGBits(processed_trng.size());
    printStats(prng_bits, "PRNG Bitstream");

    return 0;
}
