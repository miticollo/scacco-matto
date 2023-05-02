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
