/*
 BEMacFunctions.cpp
 BaseElements Plug-In
 
 Copyright 2010-2018 Goya. All rights reserved.
 For conditions of distribution and use please see the copyright notice in BEPlugin.cpp
 
 http://www.goya.com.au/baseelements/plugin
 
 */

#import "BEMacFunctions.h"
#import "BEPluginGlobalDefines.h"
#import "BEPluginUtilities.h"
#import "ProgressDialogWindowController.h"

#import <Cocoa/Cocoa.h>

#if TARGET_RT_BIG_ENDIAN
	#define ENCODING kCFStringEncodingUTF32BE
#else
	#define ENCODING kCFStringEncodingUTF32LE
#endif


#include <vector>


using namespace std;


const NSStringEncoding kEncoding_wchar_t = CFStringConvertEncodingToNSStringEncoding ( ENCODING );


NSString * NSStringFromString ( const std::string& text );
NSString * NSStringFromWString ( const std::wstring& text );
std::wstring WStringFromNSString ( const NSString * text );


const std::wstring SelectFileOrFolder ( const std::wstring& prompt, const std::wstring& in_folder, bool choose_file );


ProgressDialogWindowController* progressDialog;


void InitialiseForPlatform ( )
{
	progressDialog = nil;
}


#pragma mark -
#pragma mark String Utilities
#pragma mark -

NSString * NSStringFromString ( const std::string& text )
{
	NSString * new_string = [NSString stringWithCString: text.c_str() encoding: NSUTF8StringEncoding];
	
	return new_string;
}


/*
 NSStringFromWStringAutoPtr & WStringAutoPtrFromNSString from code at
 
 http://www.cocoabuilder.com/archive/cocoa/200434-nsstring-from-wstring.html
 */

NSString * NSStringFromWString ( const std::wstring& text )
{
	char * string_data = (char *)text.data();
	unsigned long size = text.size() * sizeof ( wchar_t );
	
	NSString* new_string = [[NSString alloc] initWithBytes: string_data length: size encoding: kEncoding_wchar_t];

	return new_string;
}


std::wstring WStringFromNSString ( const NSString * text )
{
	NSData * string_data = [text dataUsingEncoding: kEncoding_wchar_t];
	size_t size = [string_data length] / sizeof ( wchar_t );
	
	return wstring ( (wchar_t *)[string_data bytes], size );
}


#pragma mark -
#pragma mark Clipboard
#pragma mark -

const std::wstring ClipboardFormats ( void )
{
	NSArray *types = [[[NSPasteboard generalPasteboard] types] copy];
	NSMutableString *formats = [NSMutableString stringWithCapacity: 1];
	
	for ( NSString *type in types ) {
		[formats appendString: type];
		[formats appendString: @FILEMAKER_END_OF_LINE];
	}
	
	return WStringFromNSString ( (NSString*)formats );
	
} // ClipboardFormats


const std::string ClipboardText ( const std::wstring& atype )
{
	NSString * pasteboard_type = NSStringFromWString ( atype );
	NSData * pasteboard_data = [[NSPasteboard generalPasteboard] dataForType: pasteboard_type];
	NSStringEncoding string_encoding = NSUTF8StringEncoding;
	if ( [pasteboard_type containsString: @"public.utf16-plain-text"] ) { // copy fm custom menus
		string_encoding = NSUTF16LittleEndianStringEncoding;
	}
	NSString * clipboard_data = [[NSString alloc] initWithData: pasteboard_data encoding: string_encoding];
    if ( clipboard_data == nil ) {
        clipboard_data = @"";
    }
	
	return [clipboard_data cStringUsingEncoding: NSUTF8StringEncoding];

} // ClipboardText


const bool SetClipboardText ( const std::string& data, const std::wstring& atype )
{
	NSString * data_to_copy = NSStringFromString ( data );
	NSString * data_type = NSStringFromWString ( atype );
	NSArray * new_types = [NSArray arrayWithObject: data_type];
	
	[[NSPasteboard generalPasteboard] declareTypes: new_types owner: nil];
	
	//	[new_types release];
	
	return [[NSPasteboard generalPasteboard] setString: data_to_copy forType: data_type];
	
} // Set_ClipboardText


const std::vector<unsigned char> ClipboardFile ( const std::wstring& atype )
{
	NSString * pasteboard_type = NSStringFromWString ( atype );
	NSData * pasteboard_data = [[NSPasteboard generalPasteboard] dataForType: pasteboard_type];
	
	vector<unsigned char> result;
	const unsigned char * bytes = (const unsigned char *)[pasteboard_data bytes];
	result.assign ( bytes, bytes + [pasteboard_data length] );
	
	return result;
	
} // ClipboardData


const bool SetClipboardFile ( const std::vector<unsigned char>& data, const std::wstring& atype )
{
	NSData * data_to_copy = [NSData dataWithBytes: data.data() length: data.size()];
	NSString * data_type = NSStringFromWString ( atype );
	NSArray * new_types = [NSArray arrayWithObject: data_type];
	
	[[NSPasteboard generalPasteboard] declareTypes: new_types owner: nil];
	
	return [[NSPasteboard generalPasteboard] setData: data_to_copy forType: data_type];
	
} // Set_ClipboardData


#pragma mark -
#pragma mark Dialogs
#pragma mark -

const std::wstring SelectFileOrFolder ( const std::wstring& prompt, const std::wstring& in_folder, bool choose_file )
{
	
	NSOpenPanel* file_dialog = [NSOpenPanel openPanel];
	
	NSString * prompt_string = NSStringFromWString ( prompt );
	[file_dialog setMessage: prompt_string];

	NSString * default_directory = NSStringFromWString ( in_folder );
	if ( [default_directory length] != 0 ) {
		NSURL *directory_url = [NSURL fileURLWithPath: default_directory];
		[file_dialog setDirectoryURL: directory_url];
	}
	
	[file_dialog setCanChooseFiles: choose_file];
	[file_dialog setCanChooseDirectories: !choose_file];

	// allow new directories to be created when selecting directories
	if ( !choose_file ) {
		[file_dialog setCanCreateDirectories: YES];
	}
	
	if ( choose_file ) {
		[file_dialog setAllowsMultipleSelection: YES];
	}
	
	NSMutableString * file_path = [NSMutableString stringWithString: @""];
	
	if ( [file_dialog runModal ] == NSFileHandlingPanelOKButton ) {
		
		NSArray* files = [file_dialog URLs];
		NSUInteger number_of_files = [files count];
		
		// return the file paths as a value list
		
		for ( NSUInteger i = 0 ; i < number_of_files ; i++ ) {
			[file_path appendString: [[files objectAtIndex: i] path]];
			if ( i + 1 != number_of_files ) {
				[file_path appendString: @FILEMAKER_END_OF_LINE];
			}
		}
		
		// [files release];
		
	} else {
//		[file_path stringWithString: @""]; // the user cancelled
	}
	
	//	[prompt_string release];
	
	return WStringFromNSString ( file_path );
	
} // SelectFileOrFolder


const std::wstring SelectFile ( const std::wstring& prompt, const std::wstring& in_folder )
{
	return SelectFileOrFolder ( prompt, in_folder, YES );
}


const std::wstring SelectFolder ( const std::wstring& prompt, const std::wstring& in_folder )
{
	return SelectFileOrFolder ( prompt, in_folder, NO );
}


const std::wstring SaveFileDialog ( std::wstring& prompt, std::wstring& fileName, std::wstring& inFolder )
{
	NSSavePanel* file_dialog = [NSSavePanel savePanel];
	
	NSString * prompt_string = NSStringFromWString ( prompt );
	[file_dialog setTitle: prompt_string ];

	NSString * filename_string = NSStringFromWString ( fileName );
	[file_dialog setNameFieldStringValue: filename_string ];
		
	NSString * default_directory = NSStringFromWString ( inFolder );
	if ( [default_directory length] != 0 ) {
		NSURL *directory_url = [NSURL fileURLWithPath: default_directory];
		[file_dialog setDirectoryURL: directory_url];
	}
	
	[file_dialog setCanCreateDirectories: YES];
	
	NSMutableString * file_path = [NSMutableString stringWithString: @""];
	
	if ( [file_dialog runModal ] == NSFileHandlingPanelOKButton ) {
		file_path = (NSMutableString *)[[file_dialog URL] path];
	} else {
		// the user cancelled
	}
	
	//	[prompt_string release];
	//	[filename_string release];

	return WStringFromNSString ( file_path );
	
} // SaveFileDialog




const int DisplayDialog ( std::wstring& title, std::wstring& message, std::wstring& ok_button, std::wstring& cancel_button, std::wstring& alternate_button )
{
	int button_pressed = 0;
	
	NSString * title_string = NSStringFromWString ( title );
	NSString * ok_button_string = NSStringFromWString ( ok_button );
	NSString * cancel_button_string = NSStringFromWString ( cancel_button );
	NSString * alternate_button_string = NSStringFromWString ( alternate_button );
	NSString * message_string = NSStringFromWString ( message );
	
	NSInteger response = NSRunAlertPanel (  ( title_string ),
									@"%@", 
									( ok_button_string ), 
									( cancel_button_string ), 
									( alternate_button_string ), 
									( message_string )
									);
	
	//	[title_string release];
	//	[ok_button_string release];
	//	[cancel_button_string release];
	//	[alternate_button_string release];
	//	[message_string release];
	
	/*
	 translate the response so that the plug-in returns the same value for the same action
	 on both OS X and Windows
	 */
	
	switch ( response ) {
			
		case NSAlertDefaultReturn:    /* user pressed OK */
			button_pressed = kBE_OKButton;
			break;
			
		case NSAlertAlternateReturn:  /* user pressed Cancel */
			button_pressed = kBE_CancelButton;
			break;
			
		case NSAlertOtherReturn:      /* user pressed the third button */
			button_pressed = kBE_AlternateButton;
			break;
			
		case NSAlertErrorReturn:      /* an error occurred */
			break;
			
	}
	
	return button_pressed;
	
} // DisplayDialog



#pragma mark -
#pragma mark Progress Dialog
#pragma mark -


const fmx::errcode DisplayProgressDialog ( const std::wstring& title, const std::wstring& description, const long maximum, const bool can_cancel )
{
	
	fmx::errcode error = kNoError;

	if ( (progressDialog != nil) && ([progressDialog closed] == YES) ) {
			progressDialog = nil;
	}
	
	if ( progressDialog == nil ) {
		
		progressDialog = [[ProgressDialogWindowController alloc] initWithWindowNibName: @"BEProgressDialog"];

		if ( progressDialog != nil ) {

			NSString * title_string = NSStringFromWString ( title );
			NSString * description_string = NSStringFromWString ( description );
	
			[progressDialog show: title_string description: description_string maximumValue: maximum canCancel: can_cancel];

		} else {
			error = kWindowIsMissingError;
		}

	} else {
		error = kFileOrObjectIsInUse;
	}
	
	return error;
}


const fmx::errcode UpdateProgressDialog ( const long value, const std::wstring& description )
{
	fmx::errcode error = kNoError;
	
	if ( progressDialog != nil ) {
		
		NSString * description_string;
		
		if ( !description.empty() ) {
			description_string = NSStringFromWString ( description );
		} else {
			description_string = NULL;
		}
		
		error = [progressDialog update: value description: description_string];
		
		if ( [progressDialog closed] == YES ) {
			progressDialog = nil;
		}
		
	} else {
		error = kWindowIsMissingError;
	}
	
	return error;
}



#pragma mark -
#pragma mark User Preferences
#pragma mark -


const bool SetPreference ( std::wstring& key, std::wstring& value, std::wstring& domain )
{
	NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
	
	bool result = true;
	
	if ( standardUserDefaults ) {

		NSString * domain_name = NSStringFromWString ( domain );
		NSDictionary * preferences = [standardUserDefaults persistentDomainForName: domain_name];		
		
		NSString * preference_key = NSStringFromWString ( key );
		NSString * preference_value = NSStringFromWString ( value );
		
		NSMutableDictionary * new_preferences = [NSMutableDictionary dictionaryWithCapacity: [preferences count] + 1];
		[new_preferences addEntriesFromDictionary: preferences];
		[new_preferences setObject: preference_value forKey: preference_key];
		
		[standardUserDefaults setPersistentDomain: new_preferences forName: domain_name];
		[standardUserDefaults synchronize];
		
	} else {
		result = false;
	}
	
	return result;
}


const std::wstring GetPreference ( std::wstring& key, std::wstring& domain )
{
	NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
	NSString * preference_value = nil;
	
	if ( standardUserDefaults ) {
		
		[standardUserDefaults synchronize];
		
		NSString * domain_name = NSStringFromWString ( domain );
		NSDictionary * preferences = [standardUserDefaults persistentDomainForName: domain_name];		

		NSString * preference_key = NSStringFromWString ( key );
		preference_value = [preferences objectForKey: preference_key];
	}
	
	std::wstring preference = WStringFromNSString ( preference_value );
	
	return preference;
}



#pragma mark -
#pragma mark Other
#pragma mark -


const bool OpenURL ( std::wstring& url )
{	
	return [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: NSStringFromWString ( url ) ]];
}


const bool OpenFile ( std::wstring& path )
{	
	return [[NSWorkspace sharedWorkspace] openFile: NSStringFromWString ( path ) ];
}


const std::wstring get_machine_name ( )
{
	NSString * machine_name = [[NSHost currentHost] localizedName];
	return WStringFromNSString ( machine_name );
}


