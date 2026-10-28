import 'data.dart';

(List<String>, String) packageFindIn({required String stack}) {
  String stackAfterProcessing = '';
  List<String> packages = [];

  packages = stack.split(packagePrefix);

  for (int i = 0; i < packages.length; i++) {
    // checking that the package has a postfix (in my case "|")
    packages[i] = packages[i].trim();
    if (packages[i].endsWith(packagePostfix)) {
      // remove postfix
      packages[i] =
          packages[i].substring(0, packages[i].length - packagePostfix.length);
    } else {
      //the last package may not be complete
      if (i != packages.length - 1) {
        packages[i] = '';
      } else {
        stackAfterProcessing = packagePrefix + packages[i];
        // wait for the rest: parsing it now would store a point with a cut
        // timestamp and without the sensors that come later
        packages[i] = '';
      }
    }
  }
  return (packages, stackAfterProcessing);
}
