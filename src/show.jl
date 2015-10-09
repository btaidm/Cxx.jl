Base.bytestring(str::vcpp"llvm::StringRef") = bytestring(icxx"$str.data();",icxx"$str.size();")
function typename(RD::pcpp"clang::CXXRecordDecl")
    bytestring(icxx"""
      const clang::LangOptions LO;
      const clang::PrintingPolicy PP(LO);
      std::string name;
      llvm::raw_string_ostream stream(name);
      $RD->getNameForDiagnostic(stream, PP, true);
      stream.flush();
      name;
    """)
end
function typename{T<:Cxx.CxxQualType}(::Type{T})
    C = Cxx.instance(Cxx.__default_compiler__)
    QT = Cxx.cpptype(C,T)
    typename(Cxx.getAsCXXRecordDecl(QT))
end
@generated function Base.show(io::IO,x::Union{Cxx.CppValue,Cxx.CppRef})
    C = Cxx.instance(Cxx.__default_compiler__)
    QT = Cxx.cpptype(C,x)
    RD = Cxx.getAsCXXRecordDecl(x <: CppValue ? QT : Cxx.getPointeeType(QT))
    @assert RD != C_NULL
    name = typename(RD)
    ret = Expr(:block)
    push!(ret.args,:(println(io,"(",$name,$(x <: CppValue ? "" : "&"),")"," {")))
    icxx"""
    for (auto field : $RD->fields()) {
        if (field->getAccess() != clang::AS_public)
          continue;
        $:(begin
            fieldname = bytestring(icxx"return field->getName();")
            showexpr = Expr(:macrocall,symbol("@icxx_str"),"\$x.$fieldname;")
            push!(ret.args, :(print(io," .",$fieldname," = "); show(io,$showexpr); println(io)) )
            nothing
        end);
    }
    """
    push!(ret.args,:(println(io,"}")))
    ret
end
@generated function Base.show(io::IO, x::Cxx.CppPtr)
    C = Cxx.instance(Cxx.__default_compiler__)
    QT = Cxx.cpptype(C,x)
    RD = Cxx.getAsCXXRecordDecl(Cxx.getPointeeType(QT))
    @assert RD != C_NULL
    name = typename(RD)
    :( println(io,"(",$name,"*) @0x", hex(convert(UInt,x.ptr),Base.WORD_SIZE>>2) ))
end
