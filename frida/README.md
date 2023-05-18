# frida scripts

Here you can find an index of my experiments and tests with frida on iOS.

## SQLCipher

_See_ [dedicated README](sqlcipher/)

## xpc-tracer

This project has an [independent repo](https://github.com/miticollo/xpc-tracer).

## new contact created

```javascript
const processInformationAgent = ObjC.classes.NSProcessInfo.processInfo() // this is a shared object between processes
const majorVersion = parseInt(processInformationAgent.operatingSystemVersion()[0])
let executeSaveRequest: string = majorVersion >= 13 ? '- executeSaveRequest:response:authorizationContext:error:' : '- executeSaveRequest:response:error:';

Interceptor.attach(ObjC.classes.CNDataMapperContactStore[executeSaveRequest].implementation, {
    onEnter: function (args) {
        let addressBookPeople = new ObjC.Object(args[2]).$ivars["_addedContactsByIdentifier"]; // __NSDictionaryM
        let key = addressBookPeople.keyEnumerator().nextObject();
        let contact = addressBookPeople.objectForKey_(key).objectAtIndex_(0);
        console.log(
            contact.valueForKeyPath_('givenName'),
            ' --> ',
            contact.valueForKeyPath_('phoneNumbers.value.stringValue').objectAtIndex_(0)
        );
    }
});
```

## How Many Parameters Does an Undocumented Function or Method Have?

Suppose that you need to use `TCCAccessReset` function from `TCC` module, but you’re not sure about how many parameters it has or what types they are.
What can you do?

Let’s explore one potential solution to this problem.

1. Install [DyldExtractor](https://github.com/arandomdev/DyldExtractor) and [ktool](https://github.com/cxnder/ktool)
   ```shell
   python3 -m pip -vvv install dyldextractor k2l
   ```
2. Install [`ipsw`](https://github.com/blacktop/ipsw).
3. Extract [dyld_shared_cache](https://iphonedev.wiki/index.php?title=Dyld_shared_cache&oldid=6000)
   ```shell
    ipsw extract 'https://updates.cdn-apple.com/2023WinterFCS/fullrestores/032-49365/9B845C17-F18A-4B74-B25C-7E4C774723D7/iPhone10,3,iPhone10,6_16.3.1_20D67_Restore.ipsw' -d -V -r
   ```
   > **Note**<br/>
   > For this tutorial I'll use iOS 16.3.1 for iPhone X (aka iPhone10,6).
   > But it's important to use the same iOS version that it is installed on your target iDevice.

   > **Note**<br/>
   > If it fails you can download the IPSW **manually** and then
   > ```shell
   > ipsw extract ./iPhone_5.5_P3_15.7.5_19H332_Restore.ipsw -d -V
   > ```
4. Listing Framework names containing "TCC"
   ```shell
   dyldex -v 3 -l -f TCC ./20D67__iPhone10,3_6/dyld_shared_cache_arm64
   ```
   > **Note**<br/>
   > In this case I had a split cache, so I used the path for the main cache (the one without a file type).
5. Extracting the framework
   ```shell
   dyldex -v 3 -e 'TCC.framework/TCC' ./20D67__iPhone10,3_6/dyld_shared_cache_arm64
   ```
6. Extracting, if necessary, the required libraries
   ```shell
   dyldex -v 3 -e 'lib/libSystem.B.dylib' ./20D67__iPhone10,3_6/dyld_shared_cache_arm64
   dyldex -v 3 -e 'CoreFoundation.framework/CoreFoundation' ./20D67__iPhone10,3_6/dyld_shared_cache_arm64
   dyldex -v 3 -e 'lib/libbsm.0.dylib' ./20D67__iPhone10,3_6/dyld_shared_cache_arm64
   dyldex -v 3 -e 'libobjc.A.dylib' ./20D67__iPhone10,3_6/dyld_shared_cache_arm64
   ```
7. (Optional) Print exports and search `TCCAccessReset`
   ```shell
   ktool -v -5 symbols --exports ./binaries/TCC.framework/TCC
   ```
8. Download [Ghidra](https://ghidra-sre.org/).
9. Create a new project.
10. Drag and drop the `TCC` Mach-O file and its dependencies.