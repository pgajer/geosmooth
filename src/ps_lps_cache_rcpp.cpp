#include <Rcpp.h>
#include <cmath>

using namespace Rcpp;

// [[Rcpp::export]]
List rcpp_ps_lps_assemble_cached_system(
    const List& cache,
    const NumericVector& y,
    const NumericVector& response_weights,
    const double lambda_sync) {

    const List data_blocks = cache["data.blocks"];
    const List sync_blocks = cache["sync.blocks"];
    const int ncoef = as<int>(cache["ncoef"]);

    int data_nrows = 0;
    int data_nnz = 0;
    for (int ii = 0; ii < data_blocks.size(); ++ii) {
        const List db = data_blocks[ii];
        const IntegerVector index = db["index"];
        const NumericVector weights = db["weights"];
        const int q = as<int>(db["q"]);
        int n_ok = 0;
        for (int aa = 0; aa < index.size(); ++aa) {
            const int point = index[aa] - 1;
            const double rw = response_weights[point];
            const double ww = rw * weights[aa];
            if (R_finite(rw) && R_finite(ww) && ww > 0.0) {
                ++n_ok;
            }
        }
        data_nrows += n_ok;
        data_nnz += n_ok * q;
    }

    int sync_nrows = 0;
    int sync_nnz = 0;
    if (lambda_sync > 0.0 && sync_blocks.size() > 0) {
        for (int ss = 0; ss < sync_blocks.size(); ++ss) {
            const List sb = sync_blocks[ss];
            const IntegerVector point = sb["point"];
            const int q_i = as<int>(sb["q.i"]);
            const int q_j = as<int>(sb["q.j"]);
            const int n_sb = point.size();
            sync_nrows += n_sb;
            sync_nnz += n_sb * (q_i + q_j);
        }
    }

    const int rr = data_nrows + sync_nrows;
    const int nnz = data_nnz + sync_nnz;
    if (rr <= 0 || nnz <= 0) {
        stop("PS-LPS cached native system has no rows.");
    }

    IntegerVector rows(nnz);
    IntegerVector cols(nnz);
    NumericVector vals(nnz);
    NumericVector rhs(rr);

    int row_pos = 0;
    int nz_pos = 0;
    for (int ii = 0; ii < data_blocks.size(); ++ii) {
        const List db = data_blocks[ii];
        const IntegerVector index = db["index"];
        const NumericVector weights = db["weights"];
        const NumericMatrix design = db["design"];
        const IntegerVector db_cols = db["cols"];
        const int q = as<int>(db["q"]);
        for (int aa = 0; aa < index.size(); ++aa) {
            const int point = index[aa] - 1;
            const double rw = response_weights[point];
            const double ww = rw * weights[aa];
            if (!(R_finite(rw) && R_finite(ww) && ww > 0.0)) {
                continue;
            }
            const double sw = std::sqrt(ww);
            ++row_pos;
            for (int qq = 0; qq < q; ++qq) {
                rows[nz_pos] = row_pos;
                cols[nz_pos] = db_cols[qq];
                vals[nz_pos] = sw * design(aa, qq);
                ++nz_pos;
            }
            rhs[row_pos - 1] = sw * y[point];
        }
    }

    if (lambda_sync > 0.0 && sync_blocks.size() > 0) {
        const double lambda_sqrt = std::sqrt(lambda_sync);
        for (int ss = 0; ss < sync_blocks.size(); ++ss) {
            const List sb = sync_blocks[ss];
            const IntegerVector point = sb["point"];
            const NumericVector omega_sqrt = sb["omega.sqrt"];
            const IntegerVector cols_i = sb["cols.i"];
            const IntegerVector cols_j = sb["cols.j"];
            const NumericMatrix values_i = sb["values.i"];
            const NumericMatrix values_j = sb["values.j"];
            const int q_i = as<int>(sb["q.i"]);
            const int q_j = as<int>(sb["q.j"]);
            const int n_sb = point.size();
            for (int aa = 0; aa < n_sb; ++aa) {
                const double scale = lambda_sqrt * omega_sqrt[aa];
                ++row_pos;
                for (int qq = 0; qq < q_i; ++qq) {
                    rows[nz_pos] = row_pos;
                    cols[nz_pos] = cols_i[qq];
                    vals[nz_pos] = scale * values_i(aa, qq);
                    ++nz_pos;
                }
                for (int qq = 0; qq < q_j; ++qq) {
                    rows[nz_pos] = row_pos;
                    cols[nz_pos] = cols_j[qq];
                    vals[nz_pos] = -scale * values_j(aa, qq);
                    ++nz_pos;
                }
            }
        }
    }

    if (row_pos != rr || nz_pos != nnz) {
        stop("Internal PS-LPS cached native sparse assembly count mismatch.");
    }

    return List::create(
        _["rows"] = rows,
        _["cols"] = cols,
        _["vals"] = vals,
        _["rhs"] = rhs,
        _["nrow"] = rr,
        _["ncol"] = ncoef,
        _["nnz"] = nnz,
        _["data_nrow"] = data_nrows,
        _["sync_nrow"] = sync_nrows
    );
}
