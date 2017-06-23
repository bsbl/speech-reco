//
//  SKSConfiguration.swift
//  Dict
//
//  Created by Sviatoslav Zimine on 6/20/17.
//  Copyright © 2017 szimine. All rights reserved.
//

import Foundation

var SKSAppKey = "3af074831fcbb020a252dbe497176b0090c0a3422489c9b4fb1b5b00dfa9de1999529db91d4dd9bfa0b5a437cc0f375dcfdb9ff36468a86083036062ac3e7b46"
var SKSAppId = "NMDPTRIAL_sebastien_f_bel_jpmorgan_com20170613030139"
var SKSServerHost = "sslsandbox-nmdp.nuancemobility.net"
var SKSServerPort = "443"

var SKSLanguage = "!LANGUAGE!"

var SKSServerUrl = String(format: "nmsps://%@@%@:%@", SKSAppId, SKSServerHost, SKSServerPort)

// Only needed if using NLU/Bolt
var SKSNLUContextTag = "!NLU_CONTEXT_TAG!"


let LANGUAGE = SKSLanguage == "!LANGUAGE!" ? "eng-USA" : SKSLanguage

var SERVICE_HOST = "http://52.210.80.41:5000/"
var SERVICE_URL_RECORD = SERVICE_HOST + "records/u223344"

var SUBJECT_MAX_SIZE = 75
