package Freq::Isr;

use vars qw( $VERSION );
$VERSION = '0.14';

use Inline C => 'DATA',
		VERSION => '0.14',
		NAME => 'Freq::Isr';

1;

__DATA__

__C__


typedef struct {
	u_long length;
	u_long docs;
	u_long* data;
} Isr;

SV* new( char* class, SV* the_string, long docs ){

	SV* obj_ref = newSViv(0);
	SV* obj     = newSVrv(obj_ref, class);

	int slen;
	int alen;
	char* nums; 
	Isr* isr;


	int i;
	int s = 0;

// This is necessary to pass true perl strings to C...
	nums = SvPV(the_string, slen);
	alen = slen/4;
    isr = malloc( sizeof(Isr) );
	isr->data = malloc(sizeof(u_long) * alen);

//printf("alen = %u, slen = %u\nnums = %s\n", alen, slen, nums);
// A memcpy should suffice here! memcpy(isr->data, nums, slen)
//	for( i = 0; i < alen; i++ ){
//		u_long n = 0;
//		n |= (unsigned char) nums[s++]; n <<= 8;
//		n |= (unsigned char) nums[s++]; n <<= 8;
//		n |= (unsigned char) nums[s++]; n <<= 8;
//		n |= (unsigned char) nums[s++];
//printf("Creating position %u from %u, %u, %u, %u\n", n, nums[s-4],nums[s-3],nums[s-2],nums[s-1]);
//		isr->data[i] = n;
//	}
	
	memcpy( (void*)isr->data, (void*)nums, slen);
	isr->length = alen;
	isr->docs = docs;

//	sv_2mortal(the_string);

	sv_setiv(obj, (IV)isr);
	SvREADONLY_on(obj);
	return obj_ref;
}

void DESTROY(SV* obj) {
    Isr* isr = (Isr*)SvIV(SvRV(obj));
	//printf("DESTROYed an isr (%u)\n", isr->length);
    free(isr->data);
	free(isr);
}

long length(SV* obj){
	return ((Isr*)SvIV(SvRV(obj)))->length;
}

long docs(SV* obj){
	return ((Isr*)SvIV(SvRV(obj)))->docs;
}

long refcount(SV* obj){
	return SvREFCNT(obj);
}

void decref(SV* obj){
	SvREFCNT_dec(obj);
}

void incref(SV* obj){
	SvREFCNT_inc(obj);
}

void dumpisr(SV* obj){
	Isr* isr = ((Isr*)SvIV(SvRV(obj)));
	int i;
	for( i = 0; i < isr->length; i++ ){
		printf( "Integer %u is %u\n", i, isr->data[i] );
	}
	printf( "Isr size is %u, (%u docs)\n", isr->length, isr->docs );

}


SV* _doc_hash_multiword(SV* name1, ...){
	INLINE_STACK_VARS;
	u_long matches = 0;
	u_long lead_val = 0, prev_match_pos = 0;
	int end_of_isr = 0, i;
	u_long lastdoc = 0, lastdoc_tmp = 0;
	char lastdoc_str[50];
	uint no_isrs = INLINE_STACK_ITEMS - 1;
	u_long ptrs[no_isrs], abs_max;
	Isr* isrs[no_isrs];
	Isr* _eof_;

	HV* overall = newHV();
	AV* docids = newAV();
	AV* docs = newAV();
	AV* intervals = newAV();
	SV* sv_val = newSViv(1);

	_eof_ = ((Isr*)SvIV(SvRV(INLINE_STACK_ITEM(0))));
	abs_max = _eof_->data[_eof_->length-1];
	for(i = 0; i < no_isrs; i++){
//printf("assigning isr %u\n", i);
		isrs[i] = ((Isr*)SvIV(SvRV(INLINE_STACK_ITEM(i+1))));
		ptrs[i] = 0;
//printf("max position for %u is %u...\n", i, isrs[i]->data[isrs[i]->length-1]);
		abs_max = 
			(isrs[i]->data[isrs[i]->length-1] < abs_max) ? 
			 isrs[i]->data[isrs[i]->length-1] : 
			 abs_max;
	}

//printf("found abs_max %u\n", abs_max);


	while( end_of_isr == 0 ){

		int all_equal = 1;
		for(i = 0; i<no_isrs; i++){
			u_long local_lead_val = lead_val + i;
			u_long current_val;
			while( isrs[i]->data[ptrs[i]] < local_lead_val ){
				ptrs[i]++;
			}
			current_val = isrs[i]->data[ptrs[i]];
			if( current_val != local_lead_val ){
				all_equal = 0;
				lead_val = current_val - i;
				if( lead_val >= abs_max ){
					end_of_isr = 1;
					break;
				}
			}
		}

		if( all_equal == 1 ){
			matches++;
			for(i = 0; i<no_isrs; i++) ptrs[i]++;
			lastdoc_tmp = lastdoc;
			lastdoc = _docnum( _eof_, lastdoc, lead_val );
			if( lastdoc_tmp == lastdoc ){
				sv_inc(sv_val);
			}
			else {
				sv_val = newSViv(1);
				av_push(docs, sv_val);
				av_push(docids, newSViv(lastdoc));
			}
			av_push( intervals, newSViv(lead_val - prev_match_pos) );
			prev_match_pos = lead_val;
		}
	}

	av_shift(intervals); // remove first (invalid) interval.
	hv_store(overall, "MATCHES", 7, newSViv(matches), 0);
	hv_store(overall, "DOCIDS", 6, newRV_noinc((SV*)docids), 0);
	hv_store(overall, "INTERVALS", 9, newRV_noinc((SV*)intervals), 0);
	hv_store(overall, "DOCMATCHES", 10, newRV_noinc((SV*)docs), 0);
//printf("all done...found %u matches\n", matches);

	return newRV_noinc((SV*) overall);
}

SV* _doc_hash_singleword( SV* eof_ref, SV* isr_ref ){

	u_long lastdoc = 0;
	u_long lastdoc_tmp;
	u_long prev_match_pos = 0;
	u_long ptr = 0;

	HV* overall = newHV();
	AV* docids = newAV();
	AV* docs = newAV();
	AV* intervals = newAV();
    Isr* isr = ((Isr*)SvIV(SvRV( isr_ref )));
	Isr* _eof_ = ((Isr*)SvIV(SvRV( eof_ref )));
	SV* sv_val = newSViv(1);

	while( ptr < isr->length ){
		lastdoc_tmp = lastdoc;
		lastdoc = _docnum( _eof_, lastdoc, isr->data[ptr] );

		if( lastdoc_tmp == lastdoc ){
			sv_inc(sv_val);
		}
		else{
			sv_val = newSViv(1);
			av_push(docs, sv_val);
			av_push(docids, newSViv(lastdoc));
		}
		av_push(intervals, newSViv(isr->data[ptr] - prev_match_pos));
		prev_match_pos = isr->data[ptr];
		ptr++;
	}

	av_shift(intervals);
	hv_store(overall, "MATCHES", 7, newSViv(isr->length), 0);
	hv_store(overall, "DOCIDS", 6, newRV_noinc((SV*)docids), 0);
	hv_store(overall, "INTERVALS", 9, newRV_noinc((SV*)intervals), 0);
	hv_store(overall, "DOCMATCHES", 10, newRV_noinc((SV*)docs), 0);

	return newRV_noinc((SV*) overall);
}


// start - a document id serving as an index into the _eof_ isr.
// matchval - the position of the match
u_long _docnum( Isr* _eof_, u_long start, u_long matchval ){

	if( _eof_->data[start] < matchval ){
		while( _eof_->data[start] < matchval ){
			start++;
		}
	}

	return start;
}

double _doc_sigma(long matches, SV* arrayref){
	AV* docs;
	SV** sv_ref;
	SV* sv_val;
	double sum = 0;
	double avg = 0;
	uint size, i;

	if(matches == 0){
		return 0;
	}

	docs = (AV*)SvRV(arrayref);
	size = av_len(docs) + 1;
	avg = (double) matches/size;  //average matches per doc.
	for( i = 0; i < size; i++ ){
		double delta;
		sv_ref = av_fetch(docs, i, 0);
		sv_val = *sv_ref;
		delta = (SvIV(sv_val) - avg);
		sum += delta*delta;
	}

	return sqrt(sum/size); //
}

double _term_sigma(long matches, long totalsize, SV* arrayref){
	AV* intervals;
	SV** sv_ref;
	SV* sv_val;
	double sum = 0;
	double avg = 0;
	uint size, i;

	if(matches <= 1){
		return 0;
	}

	intervals = (AV*)SvRV(arrayref);
	size = av_len(intervals) + 1;
	avg = (double) totalsize/matches;
	for( i = 0; i < size; i++ ){
		double delta;
		sv_ref = av_fetch(intervals, i, 0);
		sv_val = *sv_ref;
		delta = (SvIV(sv_val) - avg);
		sum += delta*delta;
	}

	return sqrt(sum/size); //
}


