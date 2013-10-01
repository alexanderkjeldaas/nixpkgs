/* Set mtime 0 for archive elements in order to get a consistent hash.
 *
 * Author: Alexander Kjeldaas <ak@formalprivacy.com>
 */

#include <fstream>
#include <iostream>
#include <iterator>
#include <sstream>
#include <stdlib.h>
#include <vector>

using ::std::cerr;
using ::std::copy;
using ::std::endl;
using ::std::ifstream;
using ::std::ios;
using ::std::istreambuf_iterator;
using ::std::ofstream;
using ::std::ostreambuf_iterator;
using ::std::string;
using ::std::stringstream;
using ::std::vector;

void check_offset(const vector<char> &v, int offset) {
  if (offset >= v.size()) {
    cerr << "Invalid offset " << offset << " in vector of size " << v.size();
    exit(1);
  }
}

int main(int argc, const char *argv[])
{
  if (argc < 2) {
    cerr << "Usage: " << argv[0] << "<filename>\n";
    return 1;
  }

  // Slurp argv[1] into a vector
  ifstream file(argv[1], ios::binary);
  istreambuf_iterator<char> start(file), end;

  vector<char> data(start, end);

  cerr << "Stripping mtime from archive: " << argv[1] << endl;

  // The AR format is documented at 
  // http://en.wikipedia.org/wiki/Ar_%28Unix%29

  for (int offset = string("!<arch>").length() + 1; offset < data.size();) {
    offset += 16; // skip file name

    check_offset(data, offset + 12);
    // Overwrite the mtime.
    const string mtime = "0           ";
    copy(mtime.begin(), mtime.end(), data.begin() + offset);

    offset += 12 /* mtime */
      + 6 /* owner id */
      + 6 /* group id */
      + 8; /* file mode */

    check_offset(data, offset + 10);
    
    // Parse the entry length
    vector<char> vlen(data.begin() + offset, data.begin() + offset + 10);
    stringstream ss(string(vlen.begin(), vlen.end()));
    int length;
    if ((ss >> length).fail()) {
      cerr << "Could not parse length field in archive at offset " << offset 
	   << "'" << string(vlen.begin(), vlen.end()) << "'" << endl;
      return 1;
    }

    offset += 10; /* file size field */
    if (data[offset] != 0x60 ||
	data[offset + 1] != 0x0A) {
      cerr << "Invalid magic found " << data[offset] << data[offset+1] << endl;
    }
    offset += 2 + length + (length % 2);  // magic, length, padding
  }
  file.close();
  

  ofstream out(argv[1], ios::out | ios::binary | ::std::ofstream::binary);
  if (!out) {
    cerr << "Could not open " << argv[1] << " for writing!" << endl;
    return 1;
  }
  copy(data.begin(), data.end(), ostreambuf_iterator<char>(out));
  return 0;
}
