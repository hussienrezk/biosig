/*
 * Generated by asn1c-0.9.21 (http://lionet.info/asn1c)
 * From ASN.1 module "FEF-IntermediateDraft"
 * 	found in "../annexb-snacc-122001.asn1"
 */

#ifndef	_TimeSampleArrayMeasuredDataSection_H_
#define	_TimeSampleArrayMeasuredDataSection_H_


#include <asn_application.h>

/* Including external dependencies */
#include <INTEGER.h>
#include "Fraction.h"
#include "SampleArrayMeasuredDataBlock.h"
#include "HandleRef.h"
#include <asn_SEQUENCE_OF.h>
#include <constr_SEQUENCE_OF.h>
#include <constr_SEQUENCE.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Forward declarations */
struct MarkerEntryRelTim;

/* TimeSampleArrayMeasuredDataSection */
typedef struct TimeSampleArrayMeasuredDataSection {
	INTEGER_t	 numberofsubblocks;
	Fraction_t	 subblocklength;
	INTEGER_t	 subblocksize;
	struct TimeSampleArrayMeasuredDataSection__metriclist {
		A_SEQUENCE_OF(HandleRef_t) list;
		
		/* Context for parsing across buffer boundaries */
		asn_struct_ctx_t _asn_ctx;
	} metriclist;
	struct TimeSampleArrayMeasuredDataSection__tsamarkerlist {
		A_SEQUENCE_OF(struct MarkerEntryRelTim) list;
		
		/* Context for parsing across buffer boundaries */
		asn_struct_ctx_t _asn_ctx;
	} *tsamarkerlist;
	SampleArrayMeasuredDataBlock_t	 data;
	
	/* Context for parsing across buffer boundaries */
	asn_struct_ctx_t _asn_ctx;
} TimeSampleArrayMeasuredDataSection_t;

/* Implementation */
extern asn_TYPE_descriptor_t asn_DEF_TimeSampleArrayMeasuredDataSection;

#ifdef __cplusplus
}
#endif

/* Referred external types */
#include "MarkerEntryRelTim.h"

#endif	/* _TimeSampleArrayMeasuredDataSection_H_ */
